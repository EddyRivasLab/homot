use flutter_rust_bridge::frb;
use serde::{Serialize, Deserialize};
use fjall::{Config, PartitionCreateOptions,UserValue, Slice, PartitionHandle};
use core::panic;
use std::sync::atomic::AtomicI64;
use std::{collections::HashMap};
use std::i64::MAX;
use std::fs::File;
use std::io::{BufRead, BufReader, Seek};
use dashmap::DashMap;
use std::time::{Instant};
use std::cmp::Reverse;
use rayon::prelude::*;
use std::sync::{Arc, Mutex};
#[derive(Clone, Serialize, Deserialize, PartialEq)]
pub enum AnnotationType{Hmmer, Interpro, Other}

impl From<&AnnotationType> for Slice{
    fn from(val: &AnnotationType) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for AnnotationType").into()
    }
}

impl From<&UserValue> for AnnotationType{
    fn from(value: &UserValue) -> Self{
        let item: AnnotationType = rmp_serde::from_slice(&value).expect("Deserialization error for Dmap");
        item
    }
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Dmap{ // Information about each domain type
    pub domain: u32,
    pub name: String,
    pub description: String,
    pub clan_name: String,
    pub hmm_length: u32,
    pub source: AnnotationType, // what type of annotation is this from?
    // fields below here are only used for Interpro annotations
    pub ip_short: String,
    pub ip_long: String,
    pub pfam_name: String,
    pub i_type: String,
}
impl From<&Dmap> for Slice{
    fn from(val: &Dmap) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Dmap").into()
    }
}

impl From<&Slice> for Dmap{
    fn from(value: &UserValue) -> Self{
        let item: Dmap = rmp_serde::from_slice(&value).expect("Deserialization error for Dmap");
        item
    }
}

#[derive(Serialize, Deserialize, Clone)]
#[frb(non_final)]
pub struct Node{
    pub taxid: i64,
    pub parent: i64,
    #[frb(non_final)]
    pub children: Vec<i64>,
    pub rank: String,
    pub ranknum: u32,
    pub name: String,
    #[frb(non_final)]
    pub hits_below: i64,
    pub hits: Vec<i64>,
    #[frb(non_final)]
    pub my_arc_start: f64, // Not used on the Rust side, but useful for Flutter visualization
    #[frb(non_final)]
    pub my_arc_end: f64,    // Not used on the Rust side, but useful for Flutter visualization
}
impl From<&Node> for Slice{
    fn from(val: &Node) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Node").into()
    }
}

impl From<&UserValue> for Node{
    fn from(value: &UserValue) -> Self{
        let item: Node = rmp_serde::from_slice(&value).expect("Deserialization error for Node");
        item
    }
}
#[derive(Serialize, Deserialize, Clone)]
pub struct Domain{
    pub name: String,
    pub clan: String,
    pub description: String,
    pub hmm_length: u32,  // Length of the HMM for this domain
    pub seq_start: u32,
    pub seq_end: u32,
    pub hmm_start: u32,
    pub hmm_end: u32,
    pub dom_evalue: f64,
    pub full_match_start: bool,
    pub full_match_end: bool,
    pub from_blast: bool, // was this domain hit from a blast search?
    pub source: AnnotationType, // what type of annotation is this from?
    // fields below here are only used for Interpro annotations
    pub ip_short: String,
    pub ip_long: String,
    pub pfam_name: String,
    pub i_type: String,
  }
impl From<&Domain> for Slice{
    fn from(val: &Domain) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Domain").into()
    }
}

impl From<&UserValue> for Domain{
    fn from(value: &UserValue) -> Self{
        let item: Domain = rmp_serde::from_slice(&value).expect("Deserialization error for Domain");
        item
    }
}
#[derive(Serialize, Deserialize, Clone)]
pub struct Hit{
    pub name: String,  // Name of the sequence that the hit was to
    pub sequence: String,  // Sequence  that was hit
    pub taxid: i64, // taxid of the sequence we hit
    pub seq_length: u32,  // length of sequence. need this to handle hits without annotation dato
    pub seq_evalue: f64,
    pub structure_domains: Vec<Domain>,  // The (possibly-shortened) domains that make up the 
    // sequence's domain structure
    pub domains: Vec<Domain>,  // all of the domains that hit this sequence
    pub queries: Vec<Domain>,  // Queries that were hit
  }

impl From<&Hit> for Slice{
    fn from(val: &Hit) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Node").into()
    }
}

impl From<&UserValue> for Hit{
    fn from(value: &UserValue) -> Self{
        let item: Hit = rmp_serde::from_slice(&value).expect("Deserialization error for Node");
        item
    }
}

// enum for different types of input files
#[derive(PartialEq, Eq)]
pub enum DataFileType{
    DomTblOut,
    Blast,
    Infer
}



// structure that only exists for returning results

#[derive(Serialize, Deserialize, Clone)]
pub struct HitResults{
    pub categories: Vec<SigCategory>,
    pub hits: Vec<i64>,  // Must be sorted in ascending order by e-value so that the first item in the vector is the example hit
  }


impl From<&HitResults> for Slice{
    fn from(val: &HitResults) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for SigCategory").into()
    }
}

impl From<&UserValue> for HitResults{
    fn from(value: &UserValue) -> Self{
        let item: HitResults = rmp_serde::from_slice(&value).expect("Deserialization error for SigCategory");
        item
    }
}

#[derive(Serialize, Deserialize, Clone)]
pub struct SigCategory{
    pub signature: u32,  // index into structures vector in SearchResults 
    pub hits: Vec<i64>,  // Must be sorted in ascending order by e-value so that the first item in the vector is the example hit
  }


impl From<&SigCategory> for Slice{
    fn from(val: &SigCategory) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for SigCategory").into()
    }
}

impl From<&UserValue> for SigCategory{
    fn from(value: &UserValue) -> Self{
        let item: SigCategory = rmp_serde::from_slice(&value).expect("Deserialization error for SigCategory");
        item
    }
}
#[derive(Serialize, Deserialize, Clone)]
pub struct ResultsOverview{
    pub num_hits: i32,
    pub num_categories: i32,
    pub categories: Vec<SigCategory>,
    pub domains_contained: Vec<String>,
  }

#[derive(Serialize, Deserialize, Clone)]
pub struct SearchResults{
    pub succeeded: bool,
    pub message: String,
    pub depth: u32,
    pub root: i64,
    pub graph: HashMap<i64, Node>,
    pub hits: Vec<Hit>,
    pub hit_structures: Vec<u32>, // Which structure does each hit have
    pub structures: Vec<String>, // list of strings describing the domain structures of the hits
    pub domains_contained: Vec<String>,
    pub root_hits: Vec<SigCategory>
}
impl From<&SearchResults> for Slice{
    fn from(val: &SearchResults) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for SearchResults").into()
    }
}
impl From<&UserValue> for SearchResults{
    fn from(value: &UserValue) -> Self{
        let item: SearchResults = rmp_serde::from_slice(&value).expect("Deserialization error for SearchResults");
        item
    }
}

#[derive(Serialize, Deserialize, Clone)]
struct DbDomain{
    domain: u32,  //numeric ID of the domain
    clan: u32, // numeric ID of the clan, FFFF if none 
    alifrom: u32, // Start of the hit to the domain
    alito: u32,  // End of the hit to the domain
    hmmfrom: u32, // Start of the hit to the HMM
    hmmto: u32, // End of the hit to the HMM
    eval: f32, // evalue of the hit
    full_match_start: bool,  // Was the domain a full match to the start of HMM
    full_match_end: bool,  // and/or th end
}

impl From<&DbDomain> for Vec<u8>{
    fn from(val: &DbDomain) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Domain")
    }
}

impl From<&UserValue> for DbDomain{
    fn from(value: &UserValue) -> Self{
        let item: DbDomain = rmp_serde::from_slice(&value).expect("Deserialization error for Domain");
        item
    }
}
#[derive(Serialize, Deserialize, Clone)]
struct AnnotatedSequence{
    name: String, 
    sequence: String,
    length: u32,
    taxid: i64,
    domains: Vec<DbDomain>,
    structure_domains: Vec<DbDomain>,
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

fn count_hits(graph: &mut HashMap<i64, Node>, id: i64) -> i64 {
    let mut total: i64=0;   
    let children: Vec<i64>;
    if (id == -1)||(graph.len()== 0){ // empty graph
        return 0;
    }
    if let Some(node) = graph.get(&id) {
        total += node.hits.len() as i64;
        children = node.children.clone();

    } else {
        panic!("Node with taxid {} not found in graph", id);
    }

    for child_id in children {
        total += count_hits(graph, child_id as i64);
    }
    if let Some(node) = graph.get_mut(&id) {
        node.hits_below = total;
    }
    else{
        panic!("Node with taxid {} not found in graph", id);
    }
    total
}


#[frb(serialize)]
pub fn fetch_graph(annfile: String, domtblout_files: Vec<String>, eval_max: f32, eval_min: f32, dom_eval_max:f32, dom_eval_min: f32, fileType: DataFileType, 
    interpro_show_superfamily: bool, interpro_show_family: bool, interpro_show_domain: bool, interpro_show_repeat: bool, interpro_show_site: bool, 
    interpro_show_other: bool, interpro_show_pfam_names: bool) -> SearchResults{
   // println!("Starting fetch_graph");

    let mut results = SearchResults{
        succeeded: false,
        message: String::from(""),
        depth: 0,
        root: -1,
        graph: HashMap::new(),
        hits: Vec::new(),
        hit_structures: Vec::new(),
        structures: Vec::new(),
        domains_contained: Vec::new(),
        root_hits: Vec::new(),
    };

    // open the database
    let db_config = Config::new(&annfile);
    let keyspace = match db_config.open() {
        Ok(ks) => ks,
        Err(e) => {
            results.message = "Error ".to_string() + &e.to_string()+ " opening database at " +   &annfile.to_string();
            return results
        }
    };

    // Load the annotated sequences
    if !keyspace.partition_exists("annotations"){
        results.message = "Couldn't find annotations data in database ".to_string() +&annfile;
        return results
    }
    // open the annotated sequence database
    let db = match keyspace.open_partition("annotations", PartitionCreateOptions::default()){
        Ok(v) =>v,
        Err(msg) => {
            results.message = "Failed to open annotations partition, even though it exists.  Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };

    if !keyspace.partition_exists("domainidtoname"){
        // we're overwriting an existing database, so delete the partition first
        results.message = "Couldn't find domain ID to name data in database".to_string() +&annfile;
        return results
    }

    // Retrieve the clan ID->domain name mappings from the annotations DB
    let domain_db = match keyspace.open_partition("domainidtoname", PartitionCreateOptions::default()){
        Ok(v) => v,
        Err(msg) => {
            results.message = "Failed to open domainidtoname partition, even though it exists.  Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };


    let (domain_map) = match create_domain_id_map(&domain_db){
        Ok(v) => v,
        Err(msg) => {
            results.message = "Couldn't create domain ID to name map from annotations database.  Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };

    // Read all of the nodes into memory, and determine the root and depth of the tree

    let mut graph: HashMap<i64, Node>;
    let depth: u32;
    let graph_db = match keyspace.open_partition("nodes", PartitionCreateOptions::default()){
        Ok(v) =>v,
        Err(msg) => {
            results.message = "Failed to open nodes partition, even though it exists. Error was: ".to_string() + &msg.to_string();
            return results;
        }
    };

    let mut hits:Vec<Hit> = Vec::new();
    let mut hit_map:DashMap<String, Hit> = DashMap::with_shard_amount(1024);
    let root: i64;
    let mut num_domtbl_hits: i64 = 0;
    let now = Instant::now();
    // load hits from the data files
    for domtbloutfile in domtblout_files{
       // println!("searching {}", domtbloutfile);
        match read_hits_from_file(&domtbloutfile,  &mut hit_map, eval_min, eval_max, dom_eval_min, dom_eval_max, &db, 
            &domain_map, &fileType){  
            Ok(v) => {
                        num_domtbl_hits += v;
            }
            Err(msg) => {
                results.message = msg;
                return results;
            },
        }
    }
    println!{"{}ms to read domtblout files", now.elapsed().as_millis()};
    let now = Instant::now();
    // turn the hits into a sorted vector
    for item in hit_map.iter(){
        hits.push(item.value().clone());
    }
    hits.sort_by(|a, b| a.seq_evalue.total_cmp(&(b.seq_evalue)));

    println!("{}ms to create sorted vector of hits", now.elapsed().as_millis());

    // create the list of domains hit so that we can assign colors
    results.domains_contained = create_domain_list(&hits);

    let now:Instant = Instant::now();
    match build_graph_from_hits(&hits, &graph_db){
        Ok(v) =>{
            graph = v.0;
            depth = v.1;
            root = v.2;
        },
        Err(msg, )=>{
                results.message = "Error building graph: ".to_string() + &msg;
                return results;
            },
        
    }
    println!("{}ms to build graph from hits", now.elapsed().as_millis());
    let total_hits = count_hits(&mut graph, root);

    println!("Hits in domtbl(s): {}, in graph: {}, in list of hits {} ",num_domtbl_hits, total_hits, hits.len());


    // check that everyone agrees on how many hits there are
    assert!(num_domtbl_hits == total_hits);
    assert!(total_hits as usize == hits.len());
    (results.structures, results.hit_structures) = compute_signatures(&hits, &interpro_show_superfamily, &interpro_show_family,
         &interpro_show_domain, &interpro_show_repeat, &interpro_show_site, &interpro_show_other, &interpro_show_pfam_names);
    assert!(results.hit_structures.len() == hits.len());
    let temp:HitResults = find_hits_below_node(root, &graph, &results.hit_structures);
    results.succeeded = true;
    results.message = "Successfully read database".to_string();
    results.depth = depth;
    results.root = root;
    results.root_hits= temp.categories;
    results.graph = graph.into_iter().collect::<HashMap<i64, Node>>(); // Convert the DashMap into a HashMap that Dart understands.
    results.hits = hits; // must be after call to find_hits_below_node because of borrow rules
    results
}


// Wrapper that calls the right read_hits function based on file type
fn read_hits_from_file(filename: &str, hits: &mut DashMap<String, Hit>, min_seq_evalue: f32, max_seq_evalue: f32, min_dom_evalue: f32, max_dom_evalue: f32, 
    annotation_db: &PartitionHandle, domain_map: &HashMap<u32, Dmap>, fileType: &DataFileType) -> Result<i64, String>{


    let file = match File::open(filename){
        Ok(f) => f,
        Err(e) => {
            return Err(format!("Error opening file {}: {}", filename, e));
        }
    };
    let mut reader = BufReader::with_capacity(1024*1024, file);
    let first_line = (& mut reader).lines().next();

    let inferred_filetype: DataFileType;
    match first_line{
        Some(Err(e)) => return Err(format!("Error reading first line of file {}: {}", filename, e)),
        
        Some(Ok(line)) => {
           if line.starts_with('#'){
                inferred_filetype = DataFileType::DomTblOut;
           }
           else{
                inferred_filetype = DataFileType::Blast;
           }
        }
        None => return Err(format!("File {} is empty", filename)),
    }

    if *fileType == DataFileType::DomTblOut || (*fileType == DataFileType::Infer && inferred_filetype == DataFileType::DomTblOut){
        reader.rewind().unwrap(); // Back up to the start of the file
        return read_hits_from_domtblout(filename, reader, hits, min_seq_evalue, max_seq_evalue, min_dom_evalue, max_dom_evalue, annotation_db, domain_map);
    }
    else{
        reader.rewind().unwrap(); // Back up to the start of the file
        return read_hits_from_blast(filename, reader, hits, min_seq_evalue, max_seq_evalue, annotation_db, domain_map);
    }
}

// Read the hits from a HMMER domtblout file
fn read_hits_from_domtblout(filename: &str, reader: BufReader<File>, hits: &mut DashMap<String, Hit>, min_seq_evalue: f32, max_seq_evalue: f32, min_dom_evalue: f32, max_dom_evalue: f32,
annotation_db: &PartitionHandle, domain_map: &HashMap<u32, Dmap> ) -> Result<i64, String>{
    // domain_map should be safe as a HashMap because it doesn't get modified in this code

    let hit_count = AtomicI64::new(0);
    let errMsg = Arc::new(Mutex::new(String::new()));
    // Parse the lines in the domtblout file
// old serial iterator
  /*   for l in reader.lines() {
        let line = match l{
            Err(e) => return Err(format!("Error reading line in file {}: {}", filename, e)),
            Ok(l) => l,
        }; */

        reader.lines().filter_map(|line_result| line_result.ok()).par_bridge().for_each(|line| {
        if !line.starts_with('#') { // Skip comment lines
        let my_errMsg = Arc::clone(&errMsg);
     //   println!("Examining line {}", line);
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 23 {
            let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
            if msg.is_empty() { // haven't already found an error
                *msg = format!("Unable to parse {} as domtblout file due to malformed line {}", filename, line);
            }
            drop(msg);  // Unlock the mutex
            
        }
        else{
            let mut error_found= false;
            let target_name = fields[0].to_string();
            let query_name = fields[3].to_string();
            let hmm_length:u32 = match fields[5].parse(){
                Err(e) => {
                    let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse hmm_length field of {} in line {} of {}", e, fields[5], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
                    0                    
                },
                Ok(v) => v,
            };
        let seq_evalue: f64 = match fields[6].parse(){
            Ok(v) => v,
            Err(e) => {//errmsg = format!("Error parsing seq_evalue in file {}: {}", filename, e);
            let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse seq_evalue field of {} in line {} of {}", e, fields[6], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
                0.0
            }
        };

        let seq_start: u32 = match fields[17].parse(){
            Ok(v) => v,
            Err(e) => {//errmsg = format!("Error parsing seq_start in file {}: {}", filename, e);
            let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse seq_start field of {} in line {} of {}", e, fields[17], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0},
        };
        
        let seq_end: u32 = match fields[18].parse(){
            Ok(v) => v,
            Err(e) =>{
                let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse seq_end field of {} in line {} of {}", e, fields[18], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0}
        }; 

        let hmm_start: u32 = match fields[15].parse(){
            Ok(v) => v,
            Err(e) => {
                let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse hmm_start field of {} in line {} of {}", e, fields[15], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0},
        };

        let hmm_end: u32 = match fields[16].parse(){
            Ok(v) => v,
            Err(e) => {
                let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse hmm_end field of {} in line {} of {}", e, fields[16], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0},
        };

        let dom_evalue: f64= match fields[12].parse(){
            Ok(v) => v,
            Err(e) => {let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse dom_evalue field of {} in line {} of {}", e, fields[12], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0.0}   ,
        };
        
        if !error_found && seq_evalue >= min_seq_evalue.into() && seq_evalue <= max_seq_evalue.into() && dom_evalue >= min_dom_evalue.into() && dom_evalue <= max_dom_evalue.into(){
            // This parsed correctly and is a reportable hit
            hit_count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            // build the domain for this hit
            let domain = Domain {
                name: query_name.clone(),
                clan: String::new(), // Clan information not available for queries
                description: String::new(), // Description information not available for queries
                hmm_length: hmm_length,  // HMM length not available for queries
                seq_start: seq_start,
                seq_end: seq_end,
                hmm_start: hmm_start,
                hmm_end: hmm_end, 
                dom_evalue: dom_evalue,
                full_match_start: hmm_start == 1,
                full_match_end: hmm_end==hmm_length,
                from_blast: false,
                source: AnnotationType::Hmmer,
    // fields below here are only used for Interpro annotations
                    ip_short: "".to_string(),
                    ip_long: "".to_string(),
                    pfam_name: "".to_string(),
                    i_type: "".to_string(),     
            }; 

            // assume that the common case is that a search only finds one hit to each sequence, so go ahead and build the Hit
            // data structure before we see if there's already one.  This will simplify the DashMap access and reduce the
            // amount of time we hold locks, at the cost of redundant work when there are multiple hits to a sequence

            // get the annotated sequence from the db that corresponds to the target
            let res1 = match annotation_db.get(&target_name){
                Err(_why) => {
                    //errmsg =format!("Error fetching sequence {} from annotation database, reason was: {}", target_name, why);
                    None
                }
                Ok(d) => d,
            };
            let seq_ann: AnnotatedSequence = match res1{
                Some(d) => match rmp_serde::from_slice(&d){
                    Ok(d) => d,
                    Err(_msg) => {
                     //errmsg = format!("Deserialization error for Annotated Sequence, reason was: {}" , &msg.to_string());
                    AnnotatedSequence{
                        name: target_name.clone(),
                        sequence: str::repeat("X", seq_end as usize),
                        length: seq_end, // This is a fake sequence, not in the database
                        taxid: 1,  // root node if using NCBI taxonomy, figure out a better plan later
                        domains: Vec::new(),
                        structure_domains: Vec::new(),
                        real: false, // This is a fake sequence, not in the database
                    }
                    },
                },
                None => {let fake_sequence = AnnotatedSequence{
                        name: target_name.clone(),
                        sequence: str::repeat("X", seq_end as usize),
                        length: seq_end, // This is a fake sequence, not in the database
                        taxid: 1,  // root node if using NCBI taxonomy, figure out a better plan later
                        domains: Vec::new(),
                        structure_domains: Vec::new(),
                        real: false, // This is a fake sequence, not in the database
                        };
                    
                     /*    let struct_domain = DbDomain{
                            domain: 0xffff,
                            clan: 0xffff,
                            alifrom: 1,
                            alito: 1,
                            hmmfrom: 1,
                            hmmto: 1,
                            eval: 0.0,
                            full_match_start: true,
                            full_match_end: true,
                        };
                        let all_domain = struct_domain.clone();
                        fake_sequence.domains.push(all_domain);
                        fake_sequence.structure_domains.push(struct_domain);*/
                        fake_sequence
                
                },
            };

            // Convert the sequence's domain lists from database format into viewer format
            let mut our_domains = Vec::new();
            for db_domain in seq_ann.domains{
                let ddata =match domain_map.get(&db_domain.domain) {
                    None => Dmap{
                        domain: 0xffff,
                        name: "No annotation data available".to_string(),
                        description: "No annotation data available".to_string(),
                        clan_name: "No annotation data available".to_string(),
                        hmm_length: 0,
                        source: AnnotationType::Other,
                        ip_short: "".to_string(),
                        ip_long: "".to_string(),
                        pfam_name: "".to_string(),
                        i_type: "".to_string(),
                    },
                    Some(v) => v.clone(),
                };
                let the_domain = Domain{
                    name: ddata.name,
                    hmm_length: ddata.hmm_length,
                    clan: ddata.clan_name,
                    description: ddata.description,
                    seq_start: db_domain.alifrom,
                    seq_end: db_domain.alito,
                    hmm_start: db_domain.hmmfrom,
                    hmm_end: db_domain.hmmto,
                    dom_evalue: f64::from(db_domain.eval),
                    full_match_start: db_domain.full_match_start, // These aren't relevant for domain annotations
                    full_match_end: db_domain.full_match_end,
                    from_blast: false,
                    source: ddata.source,
    // fields below here are only used for Interpro annotations
                    ip_short: ddata.ip_short,
                    ip_long: ddata.ip_long,
                    pfam_name: ddata.pfam_name,
                    i_type: ddata.i_type,        
                };
                our_domains.push(the_domain);
            }

            let mut structure_domains = Vec::new();
            for db_domain in seq_ann.structure_domains{
                let ddata =match domain_map.get(&db_domain.domain) {
                    None => Dmap{
                        domain: 0xffff,
                        name: "No annotation data available".to_string(),
                        description: "No annotation data available".to_string(),
                        clan_name: "No annotation data available".to_string(),
                        hmm_length: 0,
                        source: AnnotationType::Other,
                        ip_short: "".to_string(),
                        ip_long: "".to_string(),
                        pfam_name: "".to_string(),
                        i_type: "".to_string(),
                    },
                    Some(v) => v.clone(),
                };
                let the_domain = Domain{
                    name: ddata.name,
                    seq_start: db_domain.alifrom,
                    seq_end: db_domain.alito,
                    hmm_start: db_domain.hmmfrom,
                    hmm_end: db_domain.hmmto,
                    clan: ddata.clan_name,
                    description: ddata.description,
                    hmm_length: ddata.hmm_length,
                    dom_evalue: f64::from(db_domain.eval),
                    full_match_start: db_domain.full_match_start, // These aren't relevant for domain annotations
                    full_match_end: db_domain.full_match_end,
                    from_blast: false,
                    source: ddata.source,
                    // fields below here are only used for Interpro annotations
                    ip_short: ddata.ip_short,
                    ip_long: ddata.ip_long,
                    pfam_name: ddata.pfam_name,
                    i_type: ddata.i_type,        
                };
                structure_domains.push(the_domain);
            }

            // Create a hit structure for the hit that this domtblout line described
            let hit = Hit {
                name: target_name.clone(),
                taxid: seq_ann.taxid,
                seq_length: seq_ann.sequence.len() as u32,  // Do this first to avoid borrow-after-move errors
                sequence: seq_ann.sequence,
                seq_evalue: seq_evalue as f64,
                structure_domains: structure_domains,
                domains: our_domains, // For simplicity, just include the one domain
                queries: vec![domain.clone()], // one hit
            };

            // Now, either put the new hit in the database or modify the existing one
            { // Create a block so that the fetched entry gets dropped as fast as possible
                // https://github.com/xacrimon/dashmap/issues/169 describes this pattern for insert-or-modify
                let entry = hits.entry(seq_ann.name);  // entry has a write guard on its shard to prevent concurrency issues
                match entry{
                    dashmap::mapref::entry::Entry::Occupied(mut h)=>{
                        let existing_hit = h.get_mut();
                        hit_count.fetch_add(-1,std::sync::atomic::Ordering::SeqCst); // we aren't adding a new hit after all
                        existing_hit.queries.push(domain.clone());
                        if existing_hit.seq_length < hit.seq_length{
                            existing_hit.seq_length = hit.seq_length;
                            existing_hit.sequence = hit.sequence.clone();
                        }
                        if hit.seq_evalue < existing_hit.seq_evalue{
                            existing_hit.seq_evalue = hit.seq_evalue
                        }
                    },
                    dashmap::mapref::entry::Entry::Vacant(vacant) => {vacant.insert(hit);
                        ()
                    }
                };

            }

        } // closes if that decides if reportable hit
    }// closes if that detects line with not enough fields
    } // closes if that skips comment lines
  }); // closes parallel iterator over lines in file
  // closes loop over lines in domtblout file
    let msg = errMsg.lock().unwrap();
    if msg.is_empty(){ // no error detected
        return Ok(hit_count.load(std::sync::atomic::Ordering::SeqCst));
    }
    else{
        return Err((*msg).clone());
    }
}

fn read_hits_from_blast(filename: &str, reader: BufReader<File>, hits: &mut DashMap<String, Hit>, min_seq_evalue: f32, max_seq_evalue: f32,
annotation_db: &PartitionHandle, domain_map: &HashMap<u32, Dmap> ) -> Result<i64, String>{
    // domain_map should be safe as a HashMap because it doesn't get modified in this code

    let hit_count = AtomicI64::new(0);
    let errMsg = Arc::new(Mutex::new(String::new()));
 

        reader.lines().filter_map(|line_result| line_result.ok()).par_bridge().for_each(|line| {
        if !line.starts_with('#') { // Skip comment lines
          let my_errMsg = Arc::clone(&errMsg);
     //   println!("Examining line {}", line);
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() != 12 {
            let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
            if msg.is_empty() { // haven't already found an error
                *msg = format!("Unable to parse {} as BLAST tabular output file due to malformed line {}", filename, line);
            }
            drop(msg);  // Unlock the mutex
        }

        else{
        let target_name = fields[1].to_string();
        let query_name = fields[0].to_string();
        let hmm_length:u32 = 0xFFFFF; // Not available from BLAST
            let mut error_found = false;
        let seq_evalue: f64 = match fields[10].parse(){
            Ok(v) => v,
            Err(e) => {
                    let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse seq_evalue field of {} in line {} of {}", e, fields[10], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
                0.0
            }
        };
        //println!("fields[10]: {} ", fields[10]);
        //println!("seq_evalue: {} ", seq_evalue);
        let seq_start: u32 = match fields[8].parse(){
            Ok(v) => v,
            Err(e) => {let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse seq_start field of {} in line {} of {}", e, fields[8], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0},
        };
        
        let seq_end: u32 = match fields[9].parse(){
            Ok(v) => v,
            Err(e) => {let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse seq_end field of {} in line {} of {}", e, fields[9], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0}
        }; 

        let hmm_start: u32 = match fields[6].parse(){
            Ok(v) => v,
            Err(e) => {let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse hmm_start field of {} in line {} of {}", e, fields[6], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0},
        };

        let hmm_end: u32 = match fields[7].parse(){
            Ok(v) => v,
            Err(e) => {let mut msg = my_errMsg.lock().unwrap(); // get the lock on the error message
                    if msg.is_empty() { // haven't already found an error
                        *msg = format!("Error {} encountered when trying to parse hmm_end field of {} in line {} of {}", e, fields[7], line, filename);
                        error_found = true;
                    }
                    drop(msg);  // Unlock the mutex
            0},
        };

        //BLAST doesn't report a domain evalue, so just use the seq evalue
        let dom_evalue: f64= seq_evalue;
        
        if !error_found && (seq_evalue >= min_seq_evalue.into()) && (seq_evalue <= max_seq_evalue.into()){ //BLAST doesn't have domain e-values
            // This is a reportable hit
            hit_count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            // build the domain for this hit
            let domain = Domain {
                name: query_name.clone(),
                clan: String::new(), // Clan information not available for queries
                description: String::new(), // Description information not available for queries
                hmm_length: hmm_length,  // HMM length not available for queries
                seq_start: seq_start,
                seq_end: seq_end,
                hmm_start: hmm_start,
                hmm_end: hmm_end, 
                dom_evalue: dom_evalue,
                full_match_start: true, // Don't have HMM information from BLAST, so assume full match
                full_match_end: true,   // ditto
                from_blast: true,
                source: AnnotationType::Other,
    // fields below here are only used for Interpro annotations
                ip_short: "".to_string(),
                ip_long: "".to_string(),
                pfam_name: "".to_string(),
                i_type: "".to_string(),        
            }; 

            // assume that the common case is that a search only finds one hit to each sequence, so go ahead and build the Hit
            // data structure before we see if there's already one.  This will simplify the DashMap access and reduce the
            // amount of time we hold locks, at the cost of redundant work when there are multiple hits to a sequence

            // get the annotated sequence from the db that corresponds to the target
            let res1 = match annotation_db.get(&target_name){
                Err(_why) => {
                    //errmsg =format!("Error fetching sequence {} from annotation database, reason was: {}", target_name, why);
                    None
                }
                Ok(d) => d,
            };
            let seq_ann: AnnotatedSequence = match res1{
                Some(d) => match rmp_serde::from_slice(&d){
                    Ok(d) => d,
                    Err(_msg) => {
                     //errmsg = format!("Deserialization error for Annotated Sequence, reason was: {}" , &msg.to_string());
                    AnnotatedSequence{
                        name: target_name.clone(),
                        sequence: str::repeat("X", seq_end as usize),
                        length: seq_end, // This is a fake sequence, not in the database
                        taxid: 1,  // root node if using NCBI taxonomy, figure out a better plan later
                        domains: Vec::new(),
                        structure_domains: Vec::new(),
                        real: false, // This is a fake sequence, not in the database
                    }
                    },
                },
                None => {let fake_sequence = AnnotatedSequence{
                        name: target_name.clone(),
                        sequence: str::repeat("X", seq_end as usize),
                        length: seq_end, // This is a fake sequence, not in the database
                        taxid: 1,  // root node if using NCBI taxonomy, figure out a better plan later
                        domains: Vec::new(),
                        structure_domains: Vec::new(),
                        real: false, // This is a fake sequence, not in the database
                        };
                    
                     /*    let struct_domain = DbDomain{
                            domain: 0xffff,
                            clan: 0xffff,
                            alifrom: 1,
                            alito: 1,
                            hmmfrom: 1,
                            hmmto: 1,
                            eval: 0.0,
                            full_match_start: true,
                            full_match_end: true,
                        };
                        let all_domain = struct_domain.clone();
                        fake_sequence.domains.push(all_domain);
                        fake_sequence.structure_domains.push(struct_domain);*/
                        fake_sequence
                
                },
            };

            // Convert the sequence's domain lists from database format into viewer format
            let mut our_domains = Vec::new();
            for db_domain in seq_ann.domains{
                let ddata =match domain_map.get(&db_domain.domain) {
                    None => Dmap{
                        domain: 0xffff,
                        name: "No annotation data available".to_string(),
                        description: "No annotation data available".to_string(),
                        clan_name: "No annotation data available".to_string(),
                        hmm_length: 0,
                        source: AnnotationType::Other,
                        ip_short: "".to_string(),
                        ip_long: "".to_string(),
                        pfam_name: "".to_string(),
                        i_type: "".to_string(),
                    },
                    Some(v) => v.clone(),
                };
                let the_domain = Domain{
                    name: ddata.name,
                    hmm_length: ddata.hmm_length,
                    clan: ddata.clan_name,
                    description: ddata.description,
                    seq_start: db_domain.alifrom,
                    seq_end: db_domain.alito,
                    hmm_start: db_domain.hmmfrom,
                    hmm_end: db_domain.hmmto,
                    dom_evalue: f64::from(db_domain.eval),
                    full_match_start: db_domain.full_match_start, // These aren't relevant for domain annotations
                    full_match_end: db_domain.full_match_end,
                    from_blast: false,
                    source: ddata.source,
    // fields below here are only used for Interpro annotations
                    ip_short: ddata.ip_short,
                    ip_long: ddata.ip_long,
                    pfam_name: ddata.pfam_name,
                    i_type: ddata.i_type,        
                };
                our_domains.push(the_domain);
            }

            let mut structure_domains = Vec::new();
            for db_domain in seq_ann.structure_domains{
                let ddata =match domain_map.get(&db_domain.domain) {
                    None => Dmap{
                        domain: 0xffff,
                        name: "No annotation data available".to_string(),
                        description: "No annotation data available".to_string(),
                        clan_name: "No annotation data available".to_string(),
                        hmm_length: 0,
                        source: AnnotationType::Other,
                        ip_short: "".to_string(),
                        ip_long: "".to_string(),
                        pfam_name: "".to_string(),
                        i_type: "".to_string(),
                    },
                    Some(v) => v.clone(),
                };
                let the_domain = Domain{
                    name: ddata.name,
                    seq_start: db_domain.alifrom,
                    seq_end: db_domain.alito,
                    hmm_start: db_domain.hmmfrom,
                    hmm_end: db_domain.hmmto,
                    clan: ddata.clan_name,
                    description: ddata.description,
                    hmm_length: ddata.hmm_length,
                    dom_evalue: f64::from(db_domain.eval),
                    full_match_start: db_domain.full_match_start, // These aren't relevant for domain annotations
                    full_match_end: db_domain.full_match_end,
                    from_blast: false,
                    source: ddata.source,
    // fields below here are only used for Interpro annotations
                    ip_short: ddata.ip_short,
                    ip_long: ddata.ip_long,
                    pfam_name: ddata.pfam_name,
                    i_type: ddata.i_type,        
                };
                structure_domains.push(the_domain);
            }

            // Create a hit structure for the hit that this domtblout line described
            let hit = Hit {
                name: target_name.clone(),
                taxid: seq_ann.taxid,
                seq_length: seq_ann.sequence.len() as u32,  // Do this first to avoid borrow-after-move errors
                sequence: seq_ann.sequence,
                seq_evalue: seq_evalue as f64,
                structure_domains: structure_domains,
                domains: our_domains, // For simplicity, just include the one domain
                queries: vec![domain.clone()], // one hit
            };

            // Now, either put the new hit in the database or modify the existing one
            { // Create a block so that the fetched entry gets dropped as fast as possible
                // https://github.com/xacrimon/dashmap/issues/169 describes this pattern for insert-or-modify
                let entry = hits.entry(seq_ann.name);  // entry has a write guard on its shard to prevent concurrency issues
                match entry{
                    dashmap::mapref::entry::Entry::Occupied(mut h)=>{
                        let existing_hit = h.get_mut();
                        hit_count.fetch_add(-1,std::sync::atomic::Ordering::SeqCst); // we aren't adding a new hit after all
                        existing_hit.queries.push(domain.clone());
                        if existing_hit.seq_length < hit.seq_length{
                            existing_hit.seq_length = hit.seq_length;
                            existing_hit.sequence = hit.sequence.clone();
                        }
                        if hit.seq_evalue < existing_hit.seq_evalue{
                            existing_hit.seq_evalue = hit.seq_evalue
                        }
                    },
                    dashmap::mapref::entry::Entry::Vacant(vacant) => {vacant.insert(hit);
                        ()
                    }
                };

            }

        } // closes if that decides if reportable hit
    }
    }
});

let msg = errMsg.lock().unwrap();
    if msg.is_empty(){ // no error detected
        return Ok(hit_count.load(std::sync::atomic::Ordering::SeqCst));
    }
    else{
        return Err((*msg).clone());
    }
}


// Assumes the hits vector is sorted in ascending order by e-value
// builds a graph from the list of hits
fn build_graph_from_hits(hits: &Vec<Hit>, graph_db: &PartitionHandle)-> Result<(HashMap<i64, Node>, u32, i64), String> {
    let mut root:i64 = MAX;
    let mut depth: u32 = 0;
    let mut ret_graph:HashMap<i64, Node> = HashMap::new();

    let mut hit_num: i64 = 0;  //Index into hit vector for each hit
    for hit in hits{
        if ret_graph.contains_key(&hit.taxid){ // simple case, just add this hit to the node in the graph
                let node = ret_graph.get_mut(&hit.taxid).unwrap();
                node.hits.push(hit_num);
            }
            else{ // Need to fetch the appropriate node and possibly all its parents from the graph db
                let res1 = match graph_db.get(&hit.taxid.to_string()){
                    Err(why) => return Err(format!("Error looking up taxid {} in graph DB, reason was: {}", hit.taxid, why)),
                    Ok(d) => d,
                };
                let mut node: Node = match res1{
                    Some(d) => match rmp_serde::from_slice(&d){
                            Ok(d) => d,
                            Err(msg) => return Err(format!("Error deserializing graph node, message was {}.", msg)),
                        },
                    None => return Err(format!("Couldn't find taxid {} in node DB", hit.taxid)),
                };
                if node.ranknum >= depth {
                    depth = node.ranknum+1;
                }
                if hit.taxid < root{
                    root = node.taxid;
                }
                node.children = Vec::new(); // we'll build new children list as we go for the pruned DB
                node.hits = vec![hit_num];
                ret_graph.insert(hit.taxid, node.clone());
    //            println!("Adding taxid {} to graph in main step", seq_ann.taxid);

                // Now, make sure all of the node's parents are in the graph
                while !ret_graph.contains_key(&node.parent){
                    let res1 = match graph_db.get(node.parent.to_string()){
                    Err(why) => return Err(format!("Error looking up taxid {} in graph DB, reason was: {}", node.parent, why)),
                    Ok(d) => d,
                    };
                    let mut parent: Node = match res1{
                        Some(d) => match rmp_serde::from_slice(&d){
                                Ok(d) => d,
                                Err(msg) => return Err(format!("Error deserializing graph node, message was {}.", msg)),
                        },
                        None => return Err(format!("Couldn't find taxid {} in node DB", node.parent)),
                    };
                    if parent.taxid < root{
                        root = parent.taxid;
                    }
                    parent.children = vec!(node.taxid); // we'll build the pruned tree as we go
                    parent.hits = Vec::new(); // Make sure this is empty to start with
                    ret_graph.insert(parent.taxid, parent.clone());
     //               println!("Adding taxid {} to graph in parent chain", parent.taxid);
                    node = parent;  // on to the next level up
                }

                //When we get here, either we've found some ancestor of the node or we've hit the root.
                if node.parent != node.taxid{ // we aren't at the root, but we know that the parent node is in the graph 
                    let parent = ret_graph.get_mut(&node.parent).unwrap();
                    parent.children.push(node.taxid); // add the node to the parent's child list 
                }   
            }
        hit_num +=1;
    }

    Ok((ret_graph, depth, root))
}


// Given a list of the sequences one or more searches hit, creates a list of the domains that the search hit, sorted by
// descending order of number of hits to the domain
fn create_domain_list(hits: &Vec<Hit>) -> Vec<String>{
    let mut domain_map:HashMap<String, u64> = HashMap::new();
    for hit in hits{
        for domain in &hit.queries{ // Count all the queries that hit the sequence
            match domain_map.get_mut(&domain.name){
                Some(v) => *v += 1,
                None => {
                    domain_map.insert(domain.name.clone(), 1);
                }
            }
        }
        for domain in &hit.domains{ // Count all the domains that hit the sequence
            match domain_map.get_mut(&domain.name){
                Some(v) => *v += 1,
                None => {
                    domain_map.insert(domain.name.clone(), 1);
                }
            }
        }
    }


    let mut domains:Vec<(String, u64)> = domain_map.into_iter().collect();
    domains.sort_by_key(|x| Reverse(x.1));
    let mut result = Vec::new();
    for (name, _) in domains{
        result.push(name);
    }
    result
}


// Generates a string representing the domain structure of a sequence
// Requires that the domains in its input vector are sorted in ascending 
// order by start position within the sequence
fn domains_to_structure(domains: &Vec<Domain>, interpro_show_superfamily: &bool, interpro_show_family: &bool, interpro_show_domain: &bool, interpro_show_repeat: &bool, interpro_show_site: &bool, 
    interpro_show_other: &bool, interpro_show_pfam_names: &bool)->String{
    if domains.len() == 0{
        // sequence contained no standard domains
        return "None".to_string();
       //println!("Warning: sequence contained no standard domains, returning 'None' as structure");
    }

    let mut structure = "".to_string();
    let mut sorted_domains:Vec<Domain> = domains.clone();
    sorted_domains.sort_by_key(|d| d.seq_start);
    for domain in sorted_domains{
        if domain.source == AnnotationType::Interpro { 
            // see if we want to include this type of interpro data
            if (domain.i_type == "Superfamily")&&(!*interpro_show_superfamily){
                continue;
            }
            if (domain.i_type == "Family")&&(!*interpro_show_family){
                continue;
            }
            if (domain.i_type == "Domain")&&(!*interpro_show_domain){
                continue;
            }
            if (domain.i_type == "Repeat")&&(!*interpro_show_repeat){
                continue;
            }
            if (domain.i_type == "Site")&&(!*interpro_show_site){
                continue;
            }
            if (domain.i_type != "Other")&&(!interpro_show_other){
                continue;
            }
        }
        if structure != ""{
            // There's already at least one domain in it
            structure.push_str(", ");
        }
        if(*interpro_show_pfam_names) && (domain.source == AnnotationType::Interpro) && (!domain.pfam_name.is_empty()){
            structure.push_str(&domain.pfam_name);
        }
        else{
        structure.push_str(&domain.name);
        }
    }
    print!(" {}\n", structure);
    structure    
}

// Given a list of hits, finds the set of domain signatures for those hits and creates a string 
// describing each domain signature.  Returns those signatures.
// Assigns each hit to a signature, represented as an index into the array of signatures and returns that. 
fn compute_signatures(hits: &Vec<Hit>, interpro_show_superfamily: &bool, interpro_show_family: &bool, interpro_show_domain: &bool, interpro_show_repeat: &bool, interpro_show_site: &bool, 
    interpro_show_other: &bool, interpro_show_pfam_names: &bool) -> (Vec<String>, Vec<u32>){
    let mut hit_map:HashMap<String, u32> = HashMap::new();
    let mut structures:Vec<String> = Vec::new();
    let mut hit_structures:Vec<u32> = Vec::new();
    let mut current_signature:u32= 0;

    for hit in hits{
        print!("{}", hit.name);
        let structure = domains_to_structure(&hit.structure_domains, &interpro_show_superfamily, &interpro_show_family, &interpro_show_domain, 
            &interpro_show_repeat, &interpro_show_site, &interpro_show_other, &interpro_show_pfam_names);
        match hit_map.get(&structure){
            Some(sig_number) => { // We already have a category for this signature, so assign the hit to that category
                hit_structures.push(*sig_number);
            },
            None=> { // need to create a now category
                hit_map.insert(structure.clone(), current_signature); // use hash_map for fast searching
                structures.push(structure); // keep ordered list of structure strings
                hit_structures.push(current_signature); // assign the hit to the new category
                current_signature +=1;
            }
        }
    }

    // sanity check
    assert!(hits.len() == hit_structures.len());  // should be one hit_structure for every hit
    assert!(hit_map.len() == current_signature as usize);  // number of structures should equal the number of the next structure we'd create
    // even if there are no hits in the list
    // This should work even if none of the hits have domain structures    


(structures, hit_structures)
}


// Given a graph, the root of the sub-tree to examine, and a list of the structure numbers for each hit, 
// finds all of the hits to nodes at or below the root and organizes them into categories by domain structure.
// The resulting Vec<SigCategory> is sorted in descending order by number of hits to each category, while
// the hits in each category are sorted by hit number, causing them to be sorted by e-value
#[frb(sync)]
#[frb(serialize)]
pub fn find_hits_below_node(root: i64, graph: &HashMap<i64, Node>, hit_structures: &Vec<u32>) -> HitResults{
    let mut hits: Vec<i64> = Vec::new(); 
    collect_hits(&root, graph, &mut hits);
    hits.sort(); // sorting the list of hits by # has the effect of sorting the hits by e-value
//println!("1, and we have {} hits, and hit_structures has {} values", hits.len(), hit_structures.len());
    // build the set of categories as a HashMap for fast lookup, turn into vector later
    let mut category_map: HashMap<u32, SigCategory> = HashMap::new();
//println!("about to start iterator over hits");
    for hit in &hits{
  //     println!("Processing hit {} with structure {}", hit, hit_structures[*hit as usize]);
        if category_map.contains_key(& hit_structures[*hit as usize]){
    //        println!("Adding to existing category for signature {}", hit_structures[*hit as usize]);
            // We already have an appropriate category for this hit, so just add this hit to the list
            if let Some(cat) = category_map.get_mut(&hit_structures[*hit as usize]){
                cat.hits.push(*hit);
            }
        }
        else{
            // need to create a new category
      //     println!("Creating new category for signature {}", hit_structures[*hit as usize]);
            let category = SigCategory{signature: hit_structures[*hit as usize],
                hits: vec![*hit],
            };
            category_map.insert(hit_structures[*hit as usize],category);
        }
    }
//println!("2");
    // now, convert the HashMap into a vector and sort by #hits
    let mut categories: Vec<SigCategory> = Vec::new();
    for (_id, category) in category_map{
        categories.push(category);
    }
//println!("3");
    categories.sort_by_key(|x| Reverse(x.hits.len()));
    let res: HitResults = HitResults{
        categories: categories,
        hits: hits,
    };
    res
}

// traverses the graph starting at root and gathers all of the hits at root or below into a single list
pub fn collect_hits(root: &i64, graph: &HashMap<i64, Node>, hits: &mut Vec<i64>){
    if(*root == -1 )||(graph.len() == 0){
        // empty graph
        return;
    }
    let node = &graph[&root];
    for hit in &node.hits{
  //  println!("Found hit {} as child of node{}", hit, root);

        hits.push(*hit);
    }
    for child in &node.children{
        collect_hits(child, graph, hits);
    }
}

fn create_domain_id_map(db: &fjall::PartitionHandle) -> Result<HashMap<u32, Dmap>, String>{
    let mut map:HashMap<u32, Dmap> = HashMap::new();
    for key in db.keys(){ // This would be dangerous if we didn't know that the domainidtoname partition didn't 
    // have a limited number of entries
        let keybody = match key{
            Err(why) => return Err("Error reading value from domainid data. Reason was: ".to_string() + &why.to_string()),
            Ok(k) => k,
        };

        let res1 = match db.get(keybody){
            Err(why) => return Err("Error reading data from domainid data. Reason was: ".to_string() + &why.to_string()),
            Ok(d) => d,
        };
        let ddata:Dmap = match res1{
            Some(d) => match rmp_serde::from_slice(&d){
                Err(why) => return Err("Deserialization error for Dmap: ".to_string() + &why.to_string()),
                Ok(v) =>v,
            },
            None => {return Err("Couldn't find domain that we know exists in annotations DB".to_string());},
        };

        map.insert(ddata.domain.clone(), ddata.clone());

    }
   Ok(map)
} 

