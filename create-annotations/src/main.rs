use std::io::BufReader;
use std::fs::File;
use std::io::prelude::*;
use glob::glob;
use std::collections::HashMap;
use std::path::PathBuf;
use serde::{Serialize, Deserialize};
use fjall::{Config, PersistMode, PartitionCreateOptions, UserValue, Slice};
use bio::io::fasta;
use rayon::prelude::*;
use dashmap::DashMap;
use std::time::{Instant};

#[derive(Clone, Serialize, Deserialize)]
struct DomainInfo{
    name: String,
    description: String,
    length: u32, // Length of the domain in amino acids
}

impl From<&DomainInfo> for Slice{
    fn from(val: &DomainInfo) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for DomainInfo").into()
    }
}

impl From<&UserValue> for DomainInfo{
    fn from(value: &UserValue) -> Self{
        let item: DomainInfo = rmp_serde::from_slice(&value).expect("Deserialization error for DomainInfo");
        item
    }
}

#[derive(Clone, Serialize, Deserialize)]
struct Dmap{
    domain: u16,
    name: String,
    description: String,
    clan_name: String,
    hmm_length: u32,
}

impl From<&Dmap> for Slice{
    fn from(val: &Dmap) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Dmap").into()
    }
}

impl From<&UserValue> for Dmap{
    fn from(value: &UserValue) -> Self{
        let item: Dmap = rmp_serde::from_slice(&value).expect("Deserialization error for Dmap");
        item
    }
}


#[derive(Clone, Serialize, Deserialize)]
struct Domain{
    domain: u16,  //numeric ID of the domain
    clan: u16, // numeric ID of the clan, FFFF if none 
    alifrom: u32, // Start of the hit to the domain
    alito: u32,  // End of the hit to the domain
    hmmfrom: u32, // Start of the HMM match
    hmmto: u32, // End of the HMM match
    eval: f32, // evalue of the hit
    full_match_start: bool,  // Was the domain a full match to the start of HMM
    full_match_end: bool,  // and/or th end
}

impl From<&Domain> for Vec<u8>{
    fn from(val: &Domain) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Domain")
    }
}

impl From<&UserValue> for Domain{
    fn from(value: &UserValue) -> Self{
        let item: Domain = rmp_serde::from_slice(&value).expect("Deserialization error for Domain");
        item
    }
}

#[derive(Serialize, Deserialize, Clone)]
struct AnnotatedSequence{
    name: String, 
    sequence: String,
    length: u32,
    domains: Vec<Domain>,
    structure_domains: Vec<Domain>,
    real: bool,
}

impl From<&AnnotatedSequence> for Slice{
    fn from(val: &AnnotatedSequence) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for AnnotatedSequence").into()
    }
}

impl From<&UserValue> for AnnotatedSequence{
    fn from(value: &UserValue) -> Self{
        let item: AnnotatedSequence = rmp_serde::from_slice(&value).expect("Deserialization error for AnnotatedSequence");
        item
    }
}

fn parse_domtblout(domtblout: PathBuf, clan_map:&HashMap<String, (u16, u16, String)>, domains:&DashMap<String, Vec<Domain>>){
    let fp = match File::open(&domtblout){
        Err(why) => panic!("Couldn't open {} for reading: {}", domtblout.display(), why),
        Ok(file) => file,
    };

    let freader = BufReader::new(fp);
    for hit_result in freader.lines(){
        let hit = match hit_result{
            Err(why) => panic!("Error reading line from {}: {}", domtblout.display(), why),
            Ok(h) => h,
        };
        if hit.chars().next().unwrap() == '#'{
            // comment line, skip
            continue;
        }
        else{
            let fields: Vec<&str> = hit.split_whitespace().collect();
            let sequence = fields[0].to_string();
            let dname = fields[3];
            let (did, cid, _) = match clan_map.get(dname){
                Some(vals) => vals,
                None => {
                    eprintln!("Domain {} not found in clan map", dname);
                    std::process::exit(1)
                }
            };
            let eval:f32 = fields[12].parse().expect("Error converting e-value to number");
            if eval > 0.01{
                // weak hit, ignore
                continue;
            }
            let qlen:u32 = fields[5].parse().expect("Error converting qlen to number");
            let hmmfrom:u32 = fields[15].parse().expect("Error converting hmmfrom to number");
            let hmmto:u32 = fields[16].parse().expect("Error converting hmmto to number");
            let alifrom:u32 = fields[17].parse().expect("Error converting alifrom to number");
            let alito:u32 = fields[18].parse().expect("Error converting alito to number");
            let dentry = Domain{
                domain: *did,
                clan: *cid,
                alifrom: alifrom,
                alito: alito,
		hmmfrom: hmmfrom,
		hmmto: hmmto,
                eval: eval,
                full_match_start: (hmmfrom == 1),
                full_match_end: (hmmto == qlen),   
            };

            if let Some(mut x) = domains.get_mut(&sequence){
                x.push(dentry)
            }
            else{
                domains.insert(sequence, vec!(dentry));
            }
        }

    }
}

// comment this out to defang the dead code warning
/*fn print_domainlist(the_list: &Vec<Domain>){
    for domain in the_list{
        print!("{}, {}, {}, {}, {}: ", domain.domain, domain.clan, domain.alifrom, domain.alito, domain.eval);
    }
    println!("");
}*/  

fn handle_overlaps(mut sequence: AnnotatedSequence)->AnnotatedSequence{
    // First, sort the list of domains by start position
    sequence.domains.sort_by_key(|x| (x.alifrom));  // First, sort by start position
    sequence.structure_domains = sequence.domains.clone(); // make copy into  structure domains

    // Organize the full domain list for easy display.  Goal is to have the domains with the best 
    // evalues display in the top rows of the detail list.
    // Do this by sorting the domains by evalue, then placing them in the top row where they fit
    // in ascending order by evalue

    // Sort domains in the full list of domains by evalue
    sequence.domains.sort_by(|a, b| a.eval.partial_cmp(&b.eval).unwrap_or(std::cmp::Ordering::Equal));

    let mut domain_rows = Vec::new(); // Will generate a list of rows, each row containing a list of domains
    let new_row: Vec<Domain> = Vec::new();
    domain_rows.push(new_row);
    for domain in &sequence.domains {
        let mut found_position = false;
        for row in domain_rows.iter_mut(){
            if row.is_empty() || row.last().unwrap().alito < domain.alifrom{
                // If the row is empty or the last domain in the row doesn't overlap with this one,
                // add it to the row
                row.push(domain.clone());
                found_position = true;
                break; // move on to the next domain
            }
            if row.first().unwrap().alifrom > domain.alito{
                // The new domain can go at the beginning of the row
                row.insert(0, domain.clone());
                found_position = true;
                break;  // move on to the next domain
            }

            // Otherwise, we need to search and see if there's space between
            if row.len()>2 { 
                for x in 0..row.len()-2{
                    if row[x].alito < domain.alifrom && row[x+1].alifrom > domain.alito{
                        // Found a gap, so insert the new domain here
                        row.insert(x+1, domain.clone());
                        found_position = true;
                        break; // stop looking in this row, since we've found a place for the domain
                    }
                }
            }
        }
        if found_position{
            continue; // move on to the next domain
        }
        // if we get here without finding a place for the domain, add a row
        let mut added_row: Vec<Domain> = Vec::new();
        added_row.push(domain.clone()); // there must be room, since the row is empty
        domain_rows.push(added_row);
    }

    let mut new_domains: Vec<Domain> = Vec::new();
    for mut row in domain_rows{
        new_domains.append(&mut row);
    }
    sequence.domains = new_domains; // Replace the old domain list with the new ordered one
    //print!("{} ", sequence.name);
    

    // And then, eliminate overlaps in the structure domains
    let mut current = 0;
    let mut next = 1;
    while current < sequence.structure_domains.len(){
        while next < sequence.structure_domains.len(){
            if sequence.structure_domains[next].alifrom > sequence.structure_domains[current].alito{
                // No overlap, stop checking this current and move on
                next = sequence.structure_domains.len();
            }
            else{
                // overlap
                if (sequence.structure_domains[current].alito - sequence.structure_domains[next].alifrom < 5) ||
                    (sequence.structure_domains[current].clan != 0xffff && (sequence.structure_domains[current].clan != sequence.structure_domains[next].clan)){
                    // either small overlap or domains not in same clan, so shrink the one with the
                    // worse evalue
                    if sequence.structure_domains[current].eval < sequence.structure_domains[next].eval{
                        // Current has better eval, so shrink next
                        sequence.structure_domains[next].alifrom = sequence.structure_domains[current].alito +1;
                        if sequence.structure_domains[next].alito <= sequence.structure_domains[next].alifrom || 
                            sequence.structure_domains[next].alito - sequence.structure_domains[next].alifrom <= 5{
                            // next domain was shrunk out of existence or to a tiny set, so remove it
                            sequence.structure_domains.remove(next);
                            // don't increment next, because everything slides down
                        }
                        else{
                            // next domain still exists, move on to the one after it
                            next +=1;
                        }
                    }
                    else{
                        // shrink current
                        sequence.structure_domains[current].alito = sequence.structure_domains[next].alifrom -1;
                        if sequence.structure_domains[current].alito <= sequence.structure_domains[current].alifrom ||
                            sequence.structure_domains[current].alito - sequence.structure_domains[current].alifrom <= 5{
                            // current domain was shrunk out of existence or to a tiny set, remove it
                            sequence.structure_domains.remove(current);
                            next = current +1; 
                            // because we've removed current, start checking at the domain after it
                        }
                        else{
                            // current still exists, check against the following domain
                            next+=1;
                        }
                    }
                }
                else{ // large overlap in same clan, delete the domain with the worse evalue
                    if sequence.structure_domains[current].eval < sequence.structure_domains[next].eval{
                        // keep current
                        sequence.structure_domains.remove(next);
                        // don't change either current or next as next will have slid down
                    }
                    else{
                        sequence.structure_domains.remove(current);
                        next = current +1; 
                        // Because we've removed the current domain, re-start
                        // checking at the domain that follows i
                    }
                }
            }
        }
        // Have determined that current doesn't overlap with any other domain, advance current 
        current = current+1;
        next = current +1;
    }
    sequence
}

fn parse_clanfile(clanfile: PathBuf) -> HashMap<String, (u16, u16, String)>{
    let fp = match File::open(&clanfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", clanfile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut clan_map:HashMap<String, (u16, u16, String)> = HashMap::new();
    for family_result in freader.lines(){
        let fam = match family_result{
            Err(why) => panic!("Error reading line from {}: {}", clanfile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = fam.split('\t').collect();
        let fam_id:u16 = (&fields[0])[2..].parse().expect("Error converting family ID to number");
        let clan_id:u16;
	let clan_name:String;
        if fields[1].len() > 1{
            clan_id= (&fields[1])[2..].parse().expect("Error converting clan ID to number");
	    clan_name = fields[2].to_string();
        }
        else{
            clan_id = 0xFFFF;
	    clan_name = "No Clan".to_string();
        }
        clan_map.insert(
            fields[3].to_string(),
            (fam_id, clan_id, clan_name),
        );
    }

    clan_map
}

fn parse_hmmfile(hmmfile: PathBuf) -> HashMap<String, DomainInfo>{
    let fp = match File::open(&hmmfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", hmmfile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut the_domain = DomainInfo{name: "none".to_string(), description: "none".to_string(), length: 0};

    let mut domain_map:HashMap<String, DomainInfo> = HashMap::new();
    for hmm_line in freader.lines(){
        let line = match hmm_line{
            Err(why) => panic!("Error reading line from {}: {}", hmmfile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = line.split_whitespace().collect();
        match fields[0]{
            "HMMER3/f" => 
                if the_domain.name != "none"{
                    // If we have a domain, add it to the map
                    domain_map.insert(the_domain.name.clone(), the_domain.clone());
                    the_domain = DomainInfo{
                        name: "none".to_string(),
                        description: "none".to_string(),
                        length: 0,
                    };
                },
            "NAME" => {the_domain.name = fields[1].to_string();},
            "DESC" => {
                // If the description is empty, use the name
                if fields.len() > 1{
                    the_domain.description = fields[1..].join(" ");
                }
                else{
                    the_domain.description = the_domain.name.clone();
                }
            },
            "LENG" => {
                the_domain.length = fields[1].parse().expect("Error converting length to number");
            },
            _ => {
                // Ignore other lines
            }
        };
    }
    // handle the last HMM
    if the_domain.name != "none"{
       // If we have a domain, add it to the map
       domain_map.insert(the_domain.name.clone(), the_domain.clone());
       }		    
    domain_map
}

fn write_annotated_db(domains: DashMap<String, Vec<Domain>>, clan_map: &HashMap<String, (u16, u16, String)>, domain_info: &HashMap<String, DomainInfo>, seqfile: PathBuf, ofile: String){
    let fp = match File::open(&seqfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", seqfile.display(), why),
        Ok(file) => file,
    };

    //Open and configure output database
    let keyspace = Config::new(ofile).open().expect("Unable to create output database");
    if keyspace.partition_exists("annotations"){
        // we're overwriting an existing database, so delete the partition first
        let old_db = keyspace.open_partition("annotations", PartitionCreateOptions::default()).expect("Somehow couldn't open a partition we know exists");
        keyspace.delete_partition(old_db).expect("Somehow couldn't delete a partition that we know exists");
    }
    if keyspace.partition_exists("domainidtoname"){
        // we're overwriting an existing database, so delete the partition first
        let old_db = keyspace.open_partition("domainidtoname", PartitionCreateOptions::default()).expect("Somehow couldn't open a partition we know exists");
        keyspace.delete_partition(old_db).expect("Somehow couldn't delete a partition that we know exists");
    }
    let db = keyspace.open_partition("annotations", PartitionCreateOptions::default()).expect("Unable to create output partition");
  
    // Add the domain ID -> name mappings so that the viewer doesn't need the clans file.
    let domain_db = keyspace.open_partition("domainidtoname", PartitionCreateOptions::default()).expect("Unable to create output partition");

    for key in clan_map.keys(){
        let (did, _, cname) = clan_map.get(key).expect("Couldn't find key we know exists in clan map.");
	let dinfo = domain_info.get(key).expect("Couldn't find key we know exists in domain information.");
        let foo:Dmap = Dmap{
            domain: *did,
            name: key.clone(),
	    clan_name: cname.clone(),
	    description: dinfo.description.clone(),
	    hmm_length: dinfo.length,
        };
        domain_db.insert(did.to_string(), &foo).expect("Couldn't insert entry into domain ID part of database");
    }
    //Make sure thoso mappings made it out to disk
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");

    let reader = fasta::Reader::new(fp);

    for result in reader.records(){ // iterate through the records in the sequence file
        // adding their annotation if any
        let sequence = result.expect("Error reading fasta sequence file");
    
        let annotations  = match domains.get(sequence.id()){
            Some(vals) => (*vals).clone(),
            None => Vec::new(), //Not all sequences will have domains, so handle this
        };
    
        let mut annotated = AnnotatedSequence{
            name: sequence.id().to_string(),
	    length: sequence.id().len() as u32,
            sequence: String::from_utf8(sequence.seq().to_vec()).expect("Invalid sequnce data found"),
            domains: Vec::new(),
            structure_domains: Vec::new(),
	    real: true
        };


        // Ugh, hate this copy but can't figure out a way around it 
        for domain in annotations{
            annotated.domains.push(domain.clone());
        }
        annotated = handle_overlaps(annotated);

        db.insert(&annotated.name, &annotated).expect("Failed to insert domain into output db");

    }
    //Make sure everything made it out to disk
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");
}

fn main() {
    let mut args = std::env::args().skip(1);
    if args.len() != 5{
        eprintln!("Usage: create_annotations <seqfile> <hmmfile><domtbldir> <clanfile> <outfile>");
        std::process::exit(1);
    }

    // extract arguments
    let seqfile = args.next().unwrap();
    let hmmfile = args.next().unwrap();
    let mut dname = args.next().unwrap();
    let cfile = args.next().unwrap();
    let ofile = args.next().unwrap();

    let mut now = Instant::now();
    // first, create a hashmap mapping domain names to IDs and clans 
    let clan_map:HashMap<String, (u16, u16, String)> = parse_clanfile(Into::into(cfile));
    println!("{}ms to parse clan map", now.elapsed().as_millis());

    let domain_info: HashMap<String, DomainInfo> = parse_hmmfile(Into::into(hmmfile));
    // Create pattern to match all domtblout files in domtbldir
    if dname.chars().last().unwrap() == '/'{
        dname.push_str("*.domtblout");
    }
    else{
        dname.push_str("/*.domtblout");
    }
    
    
    let domains:DashMap<String, Vec<Domain>> = DashMap::new();

    let mut dfiles = Vec::new();

    // Gather a vector of all the files in the domtblout directory so we can parse them in parallel
    for dfile in glob(&dname).expect("Couldn't find any domtbloutfiles in domtbldir"){
        match dfile{
            Ok(path) =>  dfiles.push(path),
            Err(e) => {
                eprintln!("{:?}", e);
                std::process::exit(1);       
                    },
    
            }
    }
    now = Instant::now();
    dfiles.into_par_iter().for_each(|dfile| {
    //for dfile in dfiles{
        parse_domtblout(dfile, &clan_map, &domains);
    }
    );
    println!("{}ms to parse domtblouts", now.elapsed().as_millis());
    now = Instant::now();

    write_annotated_db(domains, &clan_map, &domain_info, seqfile.into(), ofile);
    //Write the results to a database
    println!("{}ms to write annotated DB", now.elapsed().as_millis());

}
