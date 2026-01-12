use std::io::BufReader;
use std::fs::File;
use std::io::prelude::*;
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{Instant};
use clap::{Parser};
use std::fs::exists;
use xml::reader::{EventReader, XmlEvent};
use fjall::{Config, PersistMode, PartitionCreateOptions};
use bio::io::fasta;
use std::cmp::Ordering;
use create_annotations::*;



// Define command-line arguments for clap
#[derive(Parser)]
#[command(name = "create_annotations_interpro")]
#[command(about = "Create annotated sequence database from Interpro annotations and NCBI taxonomy", long_about = None)]
struct Cli {
    /// Input FASTA sequence file
    seqfile: String,
    /// Directory holding Interpro data
    interprodir: String,
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
    
    let interpro_xml: PathBuf;
    let interpro_anns: PathBuf;
    if cli.ncbidir.ends_with('/') {
        interpro_xml = PathBuf::from(format!("{}interpro.xml", cli.interprodir));
        interpro_anns = PathBuf::from(format!("{}protein2ipr.dat", cli.interprodir));
    }
    else{ 
        interpro_xml = PathBuf::from(format!("{}/interpro.xml", cli.interprodir));
        interpro_anns = PathBuf::from(format!("{}/protein2ipr.dat", cli.interprodir));
    }
    match exists(&interpro_xml){
        Err(why)=> {eprintln!("Error trying to locate interpro.xml file {}.  Error was {}", interpro_xml.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }
    match exists(&interpro_anns){
        Err(why)=> {eprintln!("Error trying to locate Interpro protein2ipr.dat file {}.  Error was {}", interpro_anns.display(), why);
            std::process::exit(1);
        },
        Ok(_) => {},
    }

    // Define paths to input files in our specified directories
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
    
    let interpro_domain_info: HashMap<String, InterproInfo>; 
    match parse_interpro_xml(&interpro_xml){
        Ok(res) => interpro_domain_info = res,
        Err(why) => {eprintln!("Error trying to process interpro.xml file {}.  Error was {}", interpro_xml.display(), why);
            std::process::exit(1);
        },
    }
    println!("{}ms to read interpro.xml", now.elapsed().as_millis());

    let now:Instant = Instant::now();
    let annotations:HashMap<String, Vec<Domain>> =  match parse_interpro_annotations(&interpro_anns){
        Ok(res) => res,
        Err(why) => {eprintln!("{}", why);
            std::process::exit(1);
        },
    };
    println!("{}ms to read protein2ipr.dat", now.elapsed().as_millis());

    let now:Instant = Instant::now();
    let merge_map: HashMap<i64, i64> = read_merged_dmp(Into::into(merge_dmp));
   println!("{}ms to create merge map", now.elapsed().as_millis());

    let now:Instant = Instant::now();
    let deleted_map: HashMap<i64, i64> = read_deleted(Into::into(deleted_dmp));
    println!("{}ms to create deleted map", now.elapsed().as_millis());

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

  
    now = Instant::now();

     write_annotated_db(annotations, &interpro_domain_info, cli.seqfile.into(), &merge_map, &deleted_map, &node_graph, &substitutions, cli.outfile);
    //Write the results to a database
    println!("{}ms to write annotated DB", now.elapsed().as_millis());
}




pub fn write_annotated_db(domains: HashMap<String, Vec<Domain>>, 
    domain_info: &HashMap<String, InterproInfo>, seqfile: PathBuf, merged_map: &HashMap<i64, i64>, deleted_map: &HashMap<i64, i64>,
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
    
    for key in domain_info.keys(){
	    let dinfo = domain_info.get(key).expect("Couldn't find key we know exists in domain information.");
        let domid_string:String = match dinfo.id.strip_prefix("IPR"){
            None => panic!("Incorrectly-formatted Interpro ID of {} found in InterproInfo struct for {}", dinfo.id, key),
            Some(val) => val.to_string(),
         };
         
        let domid =  match domid_string.parse::<u32>() {
            Ok(val2) => val2,
            Err(why) => panic!("Couldn't parse Interpro ID of {} into IPR+integer when processing InterproInfo structs, error was {}", dinfo.id, why),
        };
        let foo:Dmap = Dmap{
            domain: domid,
            name: key.clone(),
	    clan_name: "No clan information available for Interpro annotations".to_string(),
	    description: dinfo.description.clone(),
	    hmm_length: 0,
        source: AnnotationType::Interpro,
        i_type: dinfo.i_type.clone(),
        ip_long: dinfo.ip_long.clone(),
        ip_short: dinfo.ip_short.clone(),
        pfam_name: dinfo.pfam_name.clone(),
        };
        domain_db.insert(key, &foo).expect("Couldn't insert entry into domain ID part of database");
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
        let id = (sequence.id().split('|').collect::<Vec<&str>>())[1];
     //  println!("{:?}, {}", sequence.id(), id);
        let annotations  = match domains.get(id){
            Some(vals) => (*vals).clone(),
            None => Vec::new(), //Not all sequences will have domains, so handle this
        };
    
        let accession = sequence.id().to_string().split('|').skip(1).next().unwrap_or("none").to_string();

        let fields: Vec<&str> = sequence.desc().unwrap_or("none").split_whitespace().collect();
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
            domains: Vec::new(),
            structure_domains: Vec::new(),
	    real: true
        };


        // Ugh, hate this copy but can't figure out a way around it 
        for domain in annotations{
            annotated.domains.push(domain.clone());
        }

        // eliminate overlaps of the exact same domain, since that's the data we have in Interpro
        annotated.structure_domains = remove_overlaps_interpro(&annotated.domains);
        
      //  println!("{} domains found for {}", annotated.domains.len(), annotated.name);
        db.insert(&annotated.name, &annotated).expect("Failed to insert domain into output db");
    }
    //Make sure everything made it out to disk
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");
}

// removes overlaps of the same domain or shortens to remove the overlap if the overlap is short
fn remove_overlaps_interpro(domains: &Vec<Domain>) -> Vec<Domain>{
    let mut structure: Vec<Domain> = Vec::new();

    if domains.len() < 2{// can't have an overlap with 0 or 1 domain
        return structure;
    }
    let overlap_width = 5;
    
    let mut our_domains = domains.clone();
    our_domains.sort_by(|a, b| {
        if (a.alito - a.alifrom) > (b.alito - b.alifrom){
            return Ordering::Greater;
        }
        else{
            return Ordering::Less; // don't care about how domains of same length are ordered
        }

    });
    for domain in our_domains {
        let mut candidate = domain.clone(); // need a chanvgeable copy
        let mut overlaps = false;
        for existing in &structure{
            if (candidate.domain == existing.domain) && (candidate.alifrom <= existing.alito) && (candidate.alito >= existing.alifrom){
                // overlapping domains of the same type
                let mut small_overlap = false;
                 if candidate.alito >= existing.alifrom && candidate.alito <= saturating_add(existing.alifrom, overlap_width){
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
                if  small_overlap || (candidate.alifrom <=candidate.alito){
                    // large overlap or domain has shrunk to nothing, so reject the domain
                   /* println!("Rejecting domain {} {} {}-{} due to large overlap with {} {} {}-{}", 
                    domain.domain, domain.clan, domain.alifrom, domain.alito, 
                    existing.domain, existing.clan, existing.alifrom, existing.alito);*/
                    overlaps = true;
                    break; // stop looking, we know we can't add this domain
                }
            }
        }
        if !overlaps{ // We can add the possibly-modified candidate to the structure
            structure.push(candidate);
        }
    }    
        
    structure
}


fn parse_interpro_xml(filename: &PathBuf)-> Result<HashMap<String, InterproInfo>, String>{
    // Open the input file and set up the xml reader
    let file = File::open(filename).expect("Couldn't open file");

    let file_buf = BufReader::new(file);
    let parser = EventReader::new(file_buf);

    let mut ip_map: HashMap<String, InterproInfo> = HashMap::new();
    let mut in_interpro_entry: bool = false;
    let mut in_name_entry: bool = false;
    let mut in_abstract: bool = false;
    let mut in_member_list_entry: bool = false;
    let mut abstract_string: String = "".to_string();

    let mut ip_info:InterproInfo = InterproInfo{
                            id: "".to_string(),
                            ip_short: "".to_string(),
                            ip_long: "".to_string(),
                            pfam_name: "".to_string(),
                            i_type: IEntryType::Other,
                            description: "".to_string(),
                        };
    
    for event in parser{
        match event{
            Ok(XmlEvent::StartElement {name, attributes, ..})=>{
                match name.local_name.as_str(){
                    "interpro"=> { // start of text defining an intterpro entry
                        assert!(!in_interpro_entry);
                        assert!(!in_name_entry);
                        assert!(!in_member_list_entry);
                        assert!(!in_abstract);
                        in_interpro_entry = true;
                        abstract_string= "".to_string();

                        ip_info = InterproInfo{
                            id: "".to_string(),
                            ip_short: "".to_string(),
                            ip_long: "".to_string(),
                            pfam_name: "".to_string(),
                            i_type: IEntryType::Other,
                            description: "".to_string(),
                        };
                        for attrib in attributes{
                            match attrib.name.local_name.as_str(){
                                "id" => {ip_info.id = attrib.value},
                                "short_name" => {ip_info.ip_short = attrib.value},
                                "type" => {
                                    ip_info.i_type = match attrib.value.as_str(){
                                        "Homologous_superfamily" => IEntryType::Superfamily,
                                        "Family" => IEntryType::Family,
                                        "Domain" => IEntryType::Domain,
                                        "Repeat" => IEntryType::Repeat,
                                        "Conserved_site" => IEntryType::Site,
                                        "Binding_site" => IEntryType::Site,
                                        "Active_site" => IEntryType::Site,
                                        "PTM" => IEntryType::Site,
                                        _ => {eprintln!("Unknown InterPro type: {}", attrib.value); IEntryType::Other},
                                    };
                                },
                                _ => {},
                            }
                        }
                    },
                    "name" => {
                        assert!(!in_abstract);
                        assert!(in_interpro_entry);
                        assert!(!in_member_list_entry);
                        assert!(!in_name_entry);
                        in_name_entry = true;
                    },
                    "member_list" => {
                        assert!(!in_abstract);
                        assert!(in_interpro_entry);
                        assert!(!in_name_entry);
                        assert!(!in_member_list_entry);
                        in_member_list_entry = true;
                    },
                    "db_xref" =>{
                        if in_member_list_entry{ // this field gets used in many places, we only care in member lists
                            let mut pfam_found = false;
                            let mut pfam_name:String = "".to_string();
                            for attrib in attributes{
                                match attrib.name.local_name.as_str(){
                                    "db" => {
                                        if attrib.value == "PFAM"{
                                            pfam_found = true;
                                        }
                                    },
                                    "name" => {pfam_name = attrib.value},
                                    _ => {}
                                }
                            }
                            if pfam_found{
                                ip_info.pfam_name = pfam_name;
                            }
                        }
                    },
                    "abstract" => {
                        assert!(!in_abstract);
                        assert!(in_interpro_entry);
                        assert!(!in_name_entry);
                        assert!(!in_member_list_entry);
                        in_abstract = true;
                    },
                    _ => {},
                };
            },
            Ok(XmlEvent::EndElement{name}) => {
                match name.local_name.as_str(){
                    "interpro"=> {
                        assert!(in_interpro_entry);
                        assert!(!in_name_entry);
                        assert!(!in_member_list_entry);
                        assert!(!in_abstract);
                        ip_map.insert(ip_info.id.clone(), ip_info.clone());
                        in_interpro_entry = false;
                    },
                    "name" =>{
                        assert!(in_name_entry);
                        assert!(in_interpro_entry);
                        assert!(!in_member_list_entry);
                        assert!(!in_abstract);
                        in_name_entry = false;
                    },
                    "member_list" => {
                        assert!(in_interpro_entry);
                        assert!(!in_name_entry);
                        assert!(in_member_list_entry);
                        assert!(!in_abstract);
                        in_member_list_entry = false;
                    },
                    "abstract" => {
                        assert!(in_abstract);
                        assert!(in_interpro_entry);
                        assert!(!in_name_entry);
                        assert!(!in_member_list_entry);
                        ip_info.description = abstract_string.clone();
                        in_abstract = false;
                    },
                    _ => {},

                }
            },
            Ok(XmlEvent::Characters(data)) => {
                if in_name_entry {
                    ip_info.ip_long = data;
                }
                else if in_abstract{
                    abstract_string += parse_abstract_lines(data).as_str();
                }
            },
            Err(e) => {panic!("Error {} occurred", e)}
            _ => {},
        }   
    }
    return Ok(ip_map);
}

fn parse_abstract_lines(line: String) -> String{
    let no_linefeed = line.replace('\n',"");
    let trimmed_line = no_linefeed.trim();
    if trimmed_line == "\n" || trimmed_line == "," || trimmed_line ==",\n" { //discard
        return "".to_string();
    }
    else { // remove leading and trailing brackets/parentheses left by removing reference links as well as newlines
        let pruned1 = match trimmed_line.strip_prefix(')'){
            Some(data) => data,
            None => trimmed_line,
        };
        let pruned2 = match pruned1.strip_prefix(']'){
            Some(data) => data,
            None => pruned1,
        };
        let pruned3 = match pruned2.strip_suffix('('){
            Some(data) => data,
            None => pruned2,
        };
         let pruned4 = match pruned3.strip_suffix('['){
            Some(data) => data,
            None => pruned3,
        };
        return pruned4.trim().to_string();
    }   
}


//reads through the Interpro protein2ipr.dat file and creates a list of domain records for each sequence described in the file
//returns either a HashMap connecting sequence IDs to domain lists or an error saying why this could not be done
fn parse_interpro_annotations(filename: &PathBuf) -> Result<HashMap<String, Vec<Domain>>, String>{
    let mut annotations: HashMap<String, Vec<Domain>> = HashMap::new();

    let fp = match File::open(filename){
        Err(why) => return Err(format!("Could not open protein2ipr.dat file, eror was {}", why)),
        Ok(file) => file,
    };
   // let mut parsedcount = 0;
    let freader = BufReader::new(fp);
    for annotation_result in freader.lines(){
        let line = match annotation_result{
            Ok(val) => val,
            Err(why) => return Err(format!("Error reading from protein2ipr.dat file: {}",why))
        };
        let mut fields:Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 5{
            return Err(format!("Malformed line {} found in protein2ipr.dat", line));
        }

        let uniprot_name = fields[0];
        let interpro_name = fields[1];
        /*let ip_info:&InterproInfo = match domains.get(interpro_name){
            Some(val) => val,
            None => return Err(format!("Couldn't find domain information for Interpro object {} when parsing protein2ipr.dat", interpro_name)),
        };*/

        let end:u32 = match fields.pop().unwrap().parse::<u32>(){ // pop should never fail, because we checked the length of fields
            Ok(val) => val,
            Err(why) => return Err(format!("Couldn't parse last field of line {} into integer in protein2ipr.dat, error was {}", line, why)),
        };

        let start:u32 = match fields.pop().unwrap().parse::<u32>(){ // pop should never fail, because we checked the length of fields
            Ok(val) => val,
            Err(why) => return Err(format!("Couldn't parse second-to-last field of line {} into integer in protein2ipr.dat, error was {}", line, why)),
        };

        let domid_string = match interpro_name.strip_prefix("IPR"){
            None => return Err(format!("Incorrectly-formatted Interpro ID of {} found in protein2ipr.dat", interpro_name)),
            Some(val) => val,
         };
         
        let domid =  match domid_string.parse::<u32>() {
            Ok(val2) => val2,
            Err(why) => return Err(format!("Couldn't parse Interpro ID of {} into IPR+integer, error was {}", interpro_name, why)),
        };

        let new_domain:Domain = Domain{
            domain: domid,
            clan: 0xFFFF, 
            alifrom: start,
            alito: end,
            hmmfrom: 0, // Don't have the remaining info in Interpro annotations
            hmmto: 0,
            eval: 0.0,
            full_match_start: true,
            full_match_end: true,
        };

        if let Some(x) = annotations.get_mut(uniprot_name){
            x.push(new_domain)
        }
        else{
            annotations.insert(uniprot_name.to_string(), vec!(new_domain));
        }
	   // println!("{} now has {} domains", uniprot_name, annotations.get(uniprot_name).unwrap().len());
  /*       parsedcount += 1;
        if parsedcount % 100000000 == 0{
            println!("Parsed {} lines", parsedcount);
        }*/

    }

    Ok(annotations)
}