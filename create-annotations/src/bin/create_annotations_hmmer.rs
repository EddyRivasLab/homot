use std::io::BufReader;
use std::fs::File;
use std::io::prelude::*;
use glob::glob;
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{Instant};
use clap::{Parser};
use std::fs::exists;
use fjall::{Config, PersistMode, PartitionCreateOptions};
use bio::io::fasta;

use create_annotations::*;
/*use create_annotations::Node;
use create_annotations::Domain;
use create_annotations::DomainInfo;
use create_annotations::AnnotatedSequence;
use create_annotations::Dmap;
*/
fn parse_domtblout(domtblout: PathBuf, clan_map:&HashMap<String, (u16, u16, String)>, domains:&mut HashMap<String, Vec<Domain>>){
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
                domain: *did as u32,
                clan: *cid as u32,
                alifrom: alifrom,
                alito: alito,
		hmmfrom: hmmfrom,
		hmmto: hmmto,
                eval: eval,
                full_match_start: (hmmfrom == 1),
                full_match_end: (hmmto == qlen),   
            };

            if let Some(x) = domains.get_mut(&sequence){
                x.push(dentry)
            }
            else{
                domains.insert(sequence, vec!(dentry));
            }
	    
        }

    }
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


// Define command-line arguments for clap
#[derive(Parser)]
#[command(name = "create_annotations")]
#[command(about = "Create annotated sequence database from HMMER domtblout files and NCBI taxonomy", long_about = None)]
struct Cli {
    /// Input FASTA sequence file
    seqfile: String,
    /// Directory containing HMMER domtblout files
    domtbldir: String,
    /// Directory holding Pfam data
    pfamdir: String,
    /// Directory holding NCBI taxonomy files
    ncbidir: String,
    /// Output database file
    outfile: String,

    /// Optional: File containing old->new taxid mappings for use when non-canonical ranks have been compressed out of the taxonomy
    #[arg(short='n', long="no-compress")]
    no_compress: bool,
}


fn main() {
    let cli = Cli::parse();
    let mut substitutions: HashMap<i64, i64> = HashMap::new();

    // Define paths to input files in our specified directories
    let clanfile: PathBuf;
    let hmmfile: PathBuf;
    if cli.pfamdir.ends_with('/') == false{
        clanfile = PathBuf::from(format!("{}/Pfam-A.clans.tsv", cli.pfamdir));
        hmmfile = PathBuf::from(format!("{}/Pfam-A.hmm", cli.pfamdir));
    }
    else{
        clanfile = PathBuf::from(format!("{}Pfam-A.clans.tsv", cli.pfamdir));
        hmmfile = PathBuf::from(format!("{}Pfam-A.hmm", cli.pfamdir));
    }
    match exists(&clanfile){
        Err(why)=> {eprintln!("Error trying to locate clan file {}.  Error was {}", clanfile.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }
    match exists(&hmmfile){
        Err(why)=> {eprintln!("Error trying to locate HMM file {}.  Error was {}", hmmfile.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }

    let names_dmp: PathBuf;
    let nodes_dmp: PathBuf;
    let merge_dmp: PathBuf;
    let deleted_dmp: PathBuf;
    if cli.ncbidir.ends_with('/') == false{
        names_dmp = PathBuf::from(format!("{}/names.dmp", cli.ncbidir));
        nodes_dmp = PathBuf::from(format!("{}/nodes.dmp", cli.ncbidir));
        merge_dmp = PathBuf::from(format!("{}/merged.dmp", cli.ncbidir));
        deleted_dmp = PathBuf::from(format!("{}/delnodes.dmp", cli.ncbidir));
    }
    else{
        names_dmp = PathBuf::from(format!("{}names.dmp", cli.ncbidir));
        nodes_dmp = PathBuf::from(format!("{}nodes.dmp", cli.ncbidir));
        merge_dmp = PathBuf::from(format!("{}merged.dmp", cli.ncbidir));
        deleted_dmp = PathBuf::from(format!("{}delnodes.dmp", cli.ncbidir));
    }
    match exists(&names_dmp){
        Err(why)=> {eprintln!("Error trying to locate names.dmp file {}.  Error was {}", names_dmp.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }

    match exists(&nodes_dmp){
        Err(why)=> {eprintln!("Error trying to locate nodes.dmp file {}.  Error was {}", nodes_dmp.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }
    match exists(&merge_dmp){
        Err(why)=> {eprintln!("Error trying to locate merged.dmp file {}.  Error was {}", merge_dmp.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }   
    match exists(&deleted_dmp){
        Err(why)=> {eprintln!("Error trying to locate deleted.dmp file {}.  Error was {}", deleted_dmp.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }   

    let now = Instant::now();
    // first, create a hashmap mapping domain names to IDs and clans 
    let clan_map:HashMap<String, (u16, u16, String)> = parse_clanfile(Into::into(clanfile));
    println!("{}ms to parse clan map", now.elapsed().as_millis());
    let domain_info: HashMap<String, DomainInfo> = parse_hmmfile(Into::into(hmmfile));
    let mut dname = cli.domtbldir.clone();
    // Create pattern to match all domtblout files in domtbldir
    if dname.chars().last().unwrap() == '/'{
        dname.push_str("*.domtblout");
    }
    else{
        dname.push_str("/*.domtblout");
    }
    println!("Looking for domtblout files in {}", dname);
    let now:Instant = Instant::now();
    let merge_map: HashMap<i64, i64> = read_merged_dmp(Into::into(merge_dmp));
   println!("{}ms to create merge map", now.elapsed().as_millis());

    let now:Instant = Instant::now();
    let deleted_map: HashMap<i64, i64> = read_deleted(Into::into(deleted_dmp));
    println!("{}ms to create deleted map", now.elapsed().as_millis());
    
    let mut domains:HashMap<String, Vec<Domain>> = HashMap::new();
    let mut dfiles = Vec::new();
    //println!("{}ms to parse HMM file and taxid map", now.elapsed().as_millis());

    let now = Instant::now();
    let name_map: HashMap<i64, String> = read_names_dmp(Into::into(names_dmp));
    println!("{}ms to parse names.dmp", now.elapsed().as_millis());
    
    let mut now = Instant::now();   
    let full_graph:HashMap<i64, Node> = read_nodes_dmp(Into::into(nodes_dmp), &name_map);
    println!("{}ms to parse nodes.dmp", now.elapsed().as_millis());


    let node_graph: HashMap<i64, Node>;
    if !cli.no_compress{
        now = Instant::now();
        (node_graph, substitutions) = compress_taxonomy(full_graph);
        println!("{}ms to compress taxonomy", now.elapsed().as_millis());
    }
    else{
        node_graph = full_graph;
    }

    // Gather a vector of all the files in the domtblout directory
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
    for dfile in dfiles{
       parse_domtblout(dfile, &clan_map, &mut domains);
    }
    
    println!("{}ms to parse domtblouts", now.elapsed().as_millis());
    now = Instant::now();

    write_annotated_db(domains, &clan_map, &domain_info, cli.seqfile.into(), &merge_map, &deleted_map, &node_graph, &substitutions, cli.outfile);
    //Write the results to a database
    println!("{}ms to write annotated DB", now.elapsed().as_millis());
    }




fn saturating_add(a: u32, b: u32) -> u32 {
    a.checked_add(b).unwrap_or(u32::MAX)
}
fn saturating_sub(a: u32, b: u32) -> u32 {
    a.checked_sub(b).unwrap_or(0)
}


fn handle_overlaps(mut sequence:AnnotatedSequence)->AnnotatedSequence{
   if sequence.domains.len() == 0{ // no domains found, so structure_domains is empty list
      sequence.structure_domains = Vec::new();
      return sequence;
   }
   let overlap_width = 5;  // make this easy to tune
   
   // Sort the full list of domains by evalue
   sequence.domains.sort_by(|a, b| a.eval.partial_cmp(&b.eval).unwrap_or(std::cmp::Ordering::Equal));
   sequence.structure_domains = Vec::new(); // make sure this is empty

   //let mut found_overlap = false;
   for domain in &sequence.domains{

        //println!("Considering candidate domain {} {}-{} evalue {}", candidate.domain, candidate.alifrom, candidate.alito, candidate.eval);
        let mut overlaps = false;
        let mut found_non_clan_overlap = false;
        let mut candidate = domain.clone(); // make a copy so we can modify/add to list
        for existing in &sequence.structure_domains{
            let mut small_overlap = false; // reset this for every domain so we catch cases of small overlap with one 
            // and big with others.
            if (domain.alifrom <= existing.alito) && (domain.alito >= existing.alifrom){
                // fdomain overlaps an existing domain
                if domain.clan != 0xffff && domain.clan != existing.clan{
                    found_non_clan_overlap = true; // domain must go in structure because it has a non-clan overlap
                   // println!("Found non-clan overlap between {} {} {}-{} and {} {} {}-{}", domain.domain, domain.clan, domain.alifrom, domain.alito, 
                   // existing.domain, existing.clan, existing.alifrom, existing.alito);
                   // found_overlap = true;
                        break; // stop looking, we know we need this domain
                }

                if domain.alito >= existing.alifrom && domain.alito <= saturating_add(existing.alifrom, overlap_width){
                    // small overlap with start of existing domain
                   /* println!("Shrinking domain {} {} from {}-{} to {}-{} due to small overlap with {} {} {}-{}", 
                    domain.domain, domain.clan, domain.alifrom, domain.alito, domain.alifrom, saturating_sub(existing.alifrom, 1), 
                    existing.domain, existing.clan, existing.alifrom, existing.alito); */
                    if candidate.alito > saturating_sub(existing.alifrom, 1){
                        candidate.alito = saturating_sub(existing.alifrom, 1);
                    }
                    small_overlap = true;
                }
                if candidate.alifrom <= existing.alito && candidate.alifrom >= saturating_sub(existing.alito, overlap_width){
                    /*println!("Shrinking domain {} {} from {}-{} to {}-{} due to small overlap with {} {} {}-{}", 
                    domain.domain, domain.clan, domain.alifrom, domain.alito, saturating_add(existing.alito, 1), domain.alito, 
                    existing.domain, existing.clan, existing.alifrom, existing.alito);*/
                    if candidate.alifrom < saturating_add(existing.alito, 1){
                        candidate.alifrom = saturating_add(existing.alito, 1);
                    }
                    small_overlap = true;
                }
                if !small_overlap{
                    // large overlap, so reject the domain
                   /* println!("Rejecting domain {} {} {}-{} due to large overlap with {} {} {}-{}", 
                    domain.domain, domain.clan, domain.alifrom, domain.alito, 
                    existing.domain, existing.clan, existing.alifrom, existing.alito);*/
                    overlaps = true;
                    break; // stop looking, we know we can't add this domain
                }
            }
        }
        if found_non_clan_overlap{
              sequence.structure_domains.push(domain.clone()); // push the full domain because non-clan overlap
        }
        else{
            if !overlaps{ // no overlaps, so add the domain
                if candidate.alito > candidate.alifrom{ // domain still exists after any shrinking
                    sequence.structure_domains.push(candidate);
                }
            }
        }
    }
 
 
  /*if found_overlap{
      print!("Found overlaps in sequence {}:\n", sequence.name);
      print!("full domains: ");
      print_domainlist(&sequence.domains);
      print!("structure domains: ");
      print_domainlist(&sequence.structure_domains);
      print!("\n");
   } */

  
   sequence
}

pub fn write_annotated_db(domains: HashMap<String, Vec<Domain>>, clan_map: &HashMap<String, (u16, u16, String)>, 
    domain_info: &HashMap<String, DomainInfo>, seqfile: PathBuf, merged_map: &HashMap<i64, i64>, deleted_map: &HashMap<i64, i64>,
    node_graph: &HashMap<i64, Node>, substitutions: &HashMap<i64, i64>, ofile: String){
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
    if keyspace.partition_exists("nodes"){
        // we're overwriting an existing database, so delete the partition first
        let old_db = keyspace.open_partition("nodes", PartitionCreateOptions::default()).expect("Somehow couldn't open a partition we know exists");
        keyspace.delete_partition(old_db).expect("Somehow couldn't delete a partition that we know exists");
    }
    if keyspace.partition_exists("taxidsubstitutions"){
        // we're overwriting an existing database, so delete the partition first
        let old_db = keyspace.open_partition("nodes", PartitionCreateOptions::default()).expect("Somehow couldn't open a partition we know exists");
        keyspace.delete_partition(old_db).expect("Somehow couldn't delete a partition that we know exists");
    }

    let db = keyspace.open_partition("annotations", PartitionCreateOptions::default()).expect("Unable to create output partition");
  
    let subst_db = keyspace.open_partition("taxidsubstitutions", PartitionCreateOptions::default()).expect("Unable to create output partition");
    // Add the domain ID -> name mappings so that the viewer doesn't need the clans file.
    let domain_db = keyspace.open_partition("domainidtoname", PartitionCreateOptions::default()).expect("Unable to create output partition");
    let node_db = keyspace.open_partition("nodes", PartitionCreateOptions::default()).expect("Unable to create output partition");
    
    for key in clan_map.keys(){
        let (did, _, cname) = clan_map.get(key).expect("Couldn't find key we know exists in clan map.");
	let dinfo = domain_info.get(key).expect("Couldn't find key we know exists in domain information.");
        let foo:Dmap = Dmap{
            domain: *did as u32,
            name: key.clone(),
	    clan_name: cname.clone(),
	    description: dinfo.description.clone(),
	    hmm_length: dinfo.length,
        source: AnnotationType::Hmmer,
        ip_short: "".to_string(),
        ip_long: "".to_string(),
        i_type: IEntryType::Other,
        pfam_name: "".to_string(),
        };
        domain_db.insert(did.to_string(), &foo).expect("Couldn't insert entry into domain ID part of database");
    }
    //Make sure thoso mappings made it out to disk
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");


    for key in node_graph.keys(){
        let node = node_graph.get(key).expect("Couldn't find key we know exists in node graph.");
        node_db.insert(&node.taxid.to_string(), node).expect("Couldn't insert entry into nodes part of database");
    }
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");

    for key in substitutions.keys(){
        let newid = substitutions.get(key).expect("Couldn't find key we know exists in taxid substitutions.");
        subst_db.insert(&key.to_string(), newid.to_be_bytes()).expect("Couldn't insert entry into taxid substitutions part of database");
    }
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");

    let reader = fasta::Reader::new(fp);

    for result in reader.records(){ // iterate through the records in the sequence file
        // adding their annotation if any
        let sequence = result.expect("Error reading fasta sequence file");
       // println!("{:?}", sequence.desc());
        let annotations  = match domains.get(sequence.id()){
            Some(vals) => (*vals).clone(),
            None => Vec::new(), //Not all sequences will have domains, so handle this
        };
    
        let accession = sequence.id().to_string().split('|').skip(1).next().unwrap_or("none").to_string();

        let fields: Vec<&str> = sequence.desc().unwrap_or("none").split_whitespace().collect();
        let mut description: String = String::new();
        for field in &fields{
            if !field.contains('='){
                // this is part of the description, so add it to the description string
                if description.len() > 0{
                    description.push(' '); // add a space before the next part of the description
                }
                description.push_str(field);
            }
        }

        let mut taxid: i64 = -1;
        for field in fields{
            if field.starts_with("OX="){ // found taxid field
                let string_taxid = field.split("=").nth(1).unwrap();
               // let string_taxid = pieces.nth(1).unwrap();
                taxid = string_taxid.parse::<i64>().unwrap();
            }
        }

        if taxid == -1{
            println!("failed to find taxid for accession {}, description was {:?}", accession, sequence.desc());
        }
        /*let mut taxid = match tax_map.get(&accession){
            Some(t) => *t as i64,
            None => {
                eprintln!("Warning: No taxid found for accession {}, setting to -1", accession);
                -1 as i64
            }
        };*/
        if let Some(mergedid) = merged_map.get(&taxid){
            // taxid has been merged into another
            taxid = *mergedid;
        }
        if let Some(newid) = substitutions.get(&taxid){
            taxid = *newid; // remap to new taxid if needed
        }
        if !node_graph.contains_key(&taxid){
            if deleted_map.contains_key(&taxid){
                eprintln!("Warning: taxid {} for accession {} has been deleted from taxonomy, setting it to root", taxid, accession);
            }
            else{
                println!("Failed to find taxid {} in graph, setting it to root", taxid);
            }
            taxid = 1; // set to root if not found
        }
        let mut annotated = AnnotatedSequence{
            name: sequence.id().to_string(),
	    length: sequence.id().len() as u32,
            sequence: String::from_utf8(sequence.seq().to_vec()).expect("Invalid sequence data found"),
            taxid: taxid,   
            description: description,
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