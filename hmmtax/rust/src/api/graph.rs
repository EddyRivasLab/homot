use flutter_rust_bridge::frb;
use serde::{Serialize, Deserialize};
use fjall::{Config, PartitionCreateOptions,UserValue, Slice, PartitionHandle};
use core::panic;
use std::{collections::HashMap};
use std::i64::MAX;
use std::fs::File;
use std::io::{BufRead, BufReader};
use dashmap::DashMap;
use std::time::{Instant};


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
    pub children: Vec<i64>,
    pub rank: String,
    pub ranknum: u32,
    pub name: String,
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


#[derive(Serialize, Deserialize, Clone)]
pub struct SigCategory{
    pub num_hits: i32,
    pub signature: String,
    pub example: Hit, 
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
pub struct HitList{
    pub num_hits: i32,
    pub signature: String,
    pub hits: Vec<i64>,
}
impl From<&HitList> for Slice{
    fn from(val: &HitList) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for SearchResults").into()
    }
}
impl From<&UserValue> for HitList{
    fn from(value: &UserValue) -> Self{
        let item: HitList = rmp_serde::from_slice(&value).expect("Deserialization error for SearchResults");
        item
    }
}


#[derive(Serialize, Deserialize, Clone)]
pub struct SearchResults{
    pub succeeded: bool,
    pub message: String,
    pub depth: u32,
    pub root: i64,
    pub graph: HashMap<i64, Node>,
    pub results_overview: ResultsOverview,
    pub hits: Vec<Hit>,
    pub hit_lists: Vec<HitList>,
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
    domain: u16,  //numeric ID of the domain
    clan: u16, // numeric ID of the clan, FFFF if none 
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
    if let Some(mut node) = graph.get_mut(&id) {
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
pub fn fetch_graph(annfile: String, domtblout_files: Vec<String>, eval_max: f32, dom_eval_max:f32) -> SearchResults{
   // println!("Starting fetch_graph");

    let overview = ResultsOverview{
        num_hits: 0,
        num_categories: 0,
        categories: Vec::new(),
        domains_contained: Vec::new(),
    };
    let mut results = SearchResults{
        succeeded: false,
        message: String::from(""),
        depth: 0,
        root: -1,
        graph: HashMap::new(),
        hits: Vec::new(),
        results_overview: overview,
        hit_lists: Vec::new(),
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


    let (domain_map, _domain_info): (HashMap<u16, Dmap>, HashMap<String, Dmap>) = match create_domain_id_map(&domain_db){
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

    let mut num_domtbl_hits:i64 = 0;
    let mut hits:Vec<Hit> = Vec::new();
    let mut hit_map:DashMap<String, Hit> = DashMap::new();
    let root: i64;
    // load hits from the domtblout files
    for domtbloutfile in domtblout_files{
       // println!("searching {}", domtbloutfile);
        match read_hits_from_domtblout(&domtbloutfile,  &mut hit_map, 0.0, eval_max, 0.0, dom_eval_max, &db, &domain_map ) {
            Ok(v) => {
                        num_domtbl_hits += v;
            }
            Err(msg) => {
                results.message = "Error reading domtblout file ".to_string() + &domtbloutfile + ": " + &msg;
                return results;
            },
        }
    }

    let now = Instant::now();
    // turn the hits into a sorted vector
    for item in hit_map.iter(){
        hits.push(item.value().clone());
    }
    hits.sort_by(|a, b| a.seq_evalue.total_cmp(&(b.seq_evalue)));

    print!("{}ms to create sorted vector of hits", now.elapsed().as_millis());

    match build_graph_from_hits(hits, &graph_db){
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
    print!("root = {}, depth= {}", root, depth);
    let total_hits = count_hits(&mut graph, root);

    println!("Hits in domtbl(s): {}, in graph: {}",num_domtbl_hits, total_hits);
    results.succeeded = true;
    results.message = "Successfully read database".to_string();
    results.depth = depth;
    results.root = root;
    results.graph = graph.into_iter().collect::<HashMap<i64, Node>>(); // Convert the DashMap into a HashMap that Dart understands.
    results.hit_lists = Vec::new();
    results
}

fn read_hits_from_domtblout(filename: &str, hits: &mut DashMap<String, Hit>, min_seq_evalue: f32, max_seq_evalue: f32, min_dom_evalue: f32, max_dom_evalue: f32, 
annotation_db: &PartitionHandle, domain_map: &HashMap<u16, Dmap> ) -> Result<i64, String>{
    // domain_map should be safe as a HashMap because it doesn't get modified in this code
    
    // Open the domtblout file and create a BufReader
    let file = match File::open(filename){
        Ok(f) => f,
        Err(e) => {
            return Err(format!("Error opening domtblout file {}: {}", filename, e));
        }
    };
    
    let reader = BufReader::with_capacity(1024*1024, file);
    let hit_count: i64 = 0;

    // Parse the lines in the domtblout file
    let now = Instant::now(); // start a timer

    for l in reader.lines() {
        let line = match l{
            Err(e) => return Err(format!("Error reading line in file {}: {}", filename, e)),
            Ok(l) => l,
        };
        if line.starts_with('#') {
            continue; // Skip comment lines
        }
     //   println!("Examining line {}", line);
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 23 {
            return Err(format!("Malformed line in file {}: {}", filename, line));
        }

        let target_name = fields[0].to_string();
        let query_name = fields[3].to_string();
        let hmm_length:u32 = match fields[5].parse(){
                Err(_) => {
                    return Err(format!("Error converting hmmlength field of {}  to number.", fields[5]));

                }
                Ok(v) => v,
            };
        let seq_evalue: f32 = match fields[6].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing seq_evalue in file {}: {}", filename, e)),
        };

        let seq_start: u32 = match fields[17].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing seq_start in file {}: {}", filename, e)),
        };
        
        let seq_end: u32 = match fields[18].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing seq_end in file {}: {}", filename, e)),
        }; 

        let hmm_start: u32 = match fields[15].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing hmm_start in file {}: {}", filename, e)),
        };

        let hmm_end: u32 = match fields[16].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing hmm_end in file {}: {}", filename, e)),
        };

        let dom_evalue: f32= match fields[12].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing dom_evalue in file {}: {}", filename, e)),
        };
        
        if seq_evalue >= min_seq_evalue && seq_evalue <= max_seq_evalue && dom_evalue >= min_dom_evalue && dom_evalue <= max_dom_evalue{
            // This is a reportable hit

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
                dom_evalue: dom_evalue as f64,
                full_match_start: hmm_start == 1,
                full_match_end: hmm_end==hmm_length,
            }; 

            // assume that the common case is that a search only finds one hit to each sequence, so go ahead and build the Hit
            // data structure before we see if there's already one.  This will simplify the DashMap access and reduce the
            // amount of time we hold locks, at the cost of redundant work when there are multiple hits to a sequence

            // get the annotated sequence from the db that corresponds to the target
            let res1 = match annotation_db.get(&target_name){
                Err(why) => {
                    return Err(format!("Error fetching sequence {} from annotation database, reason was: {}", target_name, why));
                }
                Ok(d) => d,
            };
            let seq_ann: AnnotatedSequence = match res1{
                Some(d) => match rmp_serde::from_slice(&d){
                    Ok(d) => d,
                    Err(msg) => {
                     return Err(format!("Deserialization error for Annotated Sequence, reason was: {}" , &msg.to_string()));
                    },
                },
                None => {let mut fake_sequence = AnnotatedSequence{
                        name: target_name.clone(),
                        sequence: "No annotation data found".to_string(),
                        length: 0, // This is a fake sequence, not in the database
                        taxid: 1,  // root node if using NCBI taxonomy, figure out a better plan later
                        domains: Vec::new(),
                        structure_domains: Vec::new(),
                        real: false, // This is a fake sequence, not in the database
                        };
                    
                        let struct_domain = DbDomain{
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
                        fake_sequence.structure_domains.push(struct_domain);
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
                        existing_hit.queries.push(domain.clone());
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
    } // closes loop over lines in domtblout file
    print!("{}ms to parse domtblout file into hits", now.elapsed().as_millis());
    return Ok(hit_count);
}


// Assumes the hits vector is sorted in ascending order by e-value
// builds a graph from the list of hits
fn build_graph_from_hits(hits: Vec<Hit>, graph_db: &PartitionHandle)-> Result<(HashMap<i64, Node>, u32, i64), String> {
    let mut root:i64 = MAX;
    let mut depth: u32 = 0;
    let mut ret_graph:HashMap<i64, Node> = HashMap::new();
    let now = Instant::now();

    let hit_num: i64 = 0;  //Index into hit vector for each hit
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
    }


    print!("{}ms to build graph from hits", now.elapsed().as_millis());
    Ok((ret_graph, depth, root))
}



/* 
// Function that reads a domtblout file and adds the hits to the graph
fn read_domtblout(filename: &str, old_root: i64,  graph: &mut DashMap<i64, Node>,  hits: &mut Vec<Hit>, max_seq_evalue: f32, max_dom_evalue: f32, db: &PartitionHandle,
    graph_db: &PartitionHandle, domain_map: &HashMap<u16, Dmap>) -> Result<(i64, u32, i64), String> {

    let mut depth = 0;
    let mut root: i64 = old_root;
   // println!("starting read_domtblout, max_seq_evalue is {}, max_dom_evalue is {}", max_seq_evalue, max_dom_evalue);
    let file = match File::open(filename){
        Ok(f) => f,
        Err(e) => {
            return Err(format!("Error opening domtblout file {}: {}", filename, e));
        }
    };
    
    let reader = BufReader::with_capacity(1024*1024, file);
    let mut hit_count: i64 = 0;
    for l in reader.lines() {
        let line = match l{
            Err(e) => return Err(format!("Error reading line in file {}: {}", filename, e)),
            Ok(l) => l,
        };
        if line.starts_with('#') {
            continue; // Skip comment lines
        }
     //   println!("Examining line {}", line);
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 23 {
            return Err(format!("Malformed line in file {}: {}", filename, line));
        }

        let target_name = fields[0].to_string();
        let query_name = fields[3].to_string();
        let hmm_length:u32 = match fields[5].parse(){
                Err(_) => {
                    return Err(format!("Error converting hmmlength field of {}  to number.", fields[5]));

                }
                Ok(v) => v,
            };
        let seq_evalue: f32 = match fields[6].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing seq_evalue in file {}: {}", filename, e)),
        };

        let seq_start: u32 = match fields[17].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing seq_start in file {}: {}", filename, e)),
        };
        
        let seq_end: u32 = match fields[18].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing seq_end in file {}: {}", filename, e)),
        }; 

        let hmm_start: u32 = match fields[15].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing hmm_start in file {}: {}", filename, e)),
        };

        let hmm_end: u32 = match fields[16].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing hmm_end in file {}: {}", filename, e)),
        };

        let dom_evalue: f32= match fields[12].parse(){
            Ok(v) => v,
            Err(e) => return Err(format!("Error parsing dom_evalue in file {}: {}", filename, e)),
        };
     //   println!("seq_evalue = {}, dom_evalue = {}", seq_evalue, dom_evalue);
        if seq_evalue <= max_seq_evalue && dom_evalue <= max_dom_evalue{ // This is a reportable hit
            // get the annotated sequence from the db that corresponds to the target
          //  println!("Found hit in domtblout");
            let res1 = match db.get(&target_name){
                Err(why) => {
                    return Err(format!("Error fetching sequence {} from annotation database, reason was: {}", target_name, why));
                }
                Ok(d) => d,
            };
            let seq_ann: AnnotatedSequence = match res1{
                Some(d) => match rmp_serde::from_slice(&d){
                    Ok(d) => d,
                    Err(msg) => {
                     return Err(format!("Deserialization error for Annotated Sequence, reason was: {}" , &msg.to_string()));
                    },
                },
                None => {let mut fake_sequence = AnnotatedSequence{
                        name: target_name.clone(),
                        sequence: "No annotation data found".to_string(),
                        length: 0, // This is a fake sequence, not in the database
                        taxid: 1,  // root node if using NCBI taxonomy, figure out a better plan later
                        domains: Vec::new(),
                        structure_domains: Vec::new(),
                        real: false, // This is a fake sequence, not in the database
                        };
                    
                        let struct_domain = DbDomain{
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
                        fake_sequence.structure_domains.push(struct_domain);
                        fake_sequence
                
                    },
            };
            if seq_ann.taxid < root{
                root = seq_ann.taxid;
            }
       //     println!("Hit had taxid {}", seq_ann.taxid);
            // Create a new Hit and Domain for the hit
            let domain = Domain {
                name: query_name.clone(),
                clan: String::new(), // Clan information not available in domtblout
                description: String::new(), // Description information not available in domtblout
                hmm_length: hmm_length,  // HMM length not available in domtblout
                seq_start: seq_start,
                seq_end: seq_end,
                hmm_start: hmm_start,
                hmm_end: hmm_end, 
                dom_evalue: dom_evalue as f64,
                full_match_start: hmm_start == 1,
                full_match_end: hmm_end==hmm_length,
            };

            let mut our_domains = Vec::new();
                for db_domain in seq_ann.domains{
                    let ddata =match domain_map.get(&db_domain.domain) {
                        None => Dmap{
                            domain: 0xffff,
                            name: "No annotation data available".to_string(),
                            description: "No annotation data available".to_string(),
                            clan_name: "No annotation data available".to_string(),
                            hmm_length: 0,
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
                    };
                    structure_domains.push(the_domain);
                }
            let hit = Hit {
                name: target_name.clone(),
                sequence: String::new(), // Sequence information not available in domtblout
                seq_length: seq_ann.sequence.len() as u32,  // Sequence length not available in domtblout
                seq_evalue: seq_evalue as f64,
                structure_domains: structure_domains,
                domains: our_domains, // For simplicity, just include the one domain
                queries: vec![domain.clone()],
            };

            if graph.contains_key(&seq_ann.taxid){ // simple case, just add this hit to the node in the graph
                let mut node = graph.get_mut(&seq_ann.taxid).unwrap();
                node.hits.push(hit);
                if node.ranknum >= depth{ // assume ranknum zero-indexed
                    depth = node.ranknum+1;
                }
            }
            else{ // Need to fetch the appropriate node and possibly all its parents from the graph db
                let res1 = match graph_db.get(&seq_ann.taxid.to_string()){
                    Err(why) => return Err(format!("Error looking up taxid {} in graph DB, reason was: {}", seq_ann.taxid, why)),
                    Ok(d) => d,
                };
                let mut node: Node = match res1{
                    Some(d) => match rmp_serde::from_slice(&d){
                            Ok(d) => d,
                            Err(msg) => return Err(format!("Error deserializing graph node, message was {}.", msg)),
                        },
                    None => return Err(format!("Couldn't find taxid {} in node DB", seq_ann.taxid)),
                };
                if node.ranknum >= depth {
                    depth = node.ranknum+1;
                }
                node.children = Vec::new(); // we'll build new children list as we go for the pruned DB
                node.hits = vec![hit];
                graph.insert(seq_ann.taxid, node.clone());
    //            println!("Adding taxid {} to graph in main step", seq_ann.taxid);

                // Now, make sure all of the node's parents are in the graph
                while !graph.contains_key(&node.parent){
                    let res1 = match graph_db.get(node.parent.to_string()){
                    Err(why) => return Err(format!("Error looking up taxid {} in graph DB, reason was: {}", seq_ann.taxid, why)),
                    Ok(d) => d,
                    };
                    let mut parent: Node = match res1{
                        Some(d) => match rmp_serde::from_slice(&d){
                                Ok(d) => d,
                                Err(msg) => return Err(format!("Error deserializing graph node, message was {}.", msg)),
                        },
                        None => return Err(format!("Couldn't find taxid {} in node DB", seq_ann.taxid)),
                    };
                    if parent.taxid < root{
                        root = parent.taxid;
                    }
                    parent.children = vec!(node.taxid); // we'll build the pruned tree as we go
                    parent.hits = Vec::new(); // Make sure this is empty to start with
                    graph.insert(parent.taxid, parent.clone());
     //               println!("Adding taxid {} to graph in parent chain", parent.taxid);
                    node = parent;  // on to the next level up
                }

                //When we get here, either we've found some ancestor of the node or we've hit the root.
                if node.parent != node.taxid{ // we aren't at the root, but we know that the parent node is in the graph 
                    let mut parent = graph.get_mut(&node.parent).unwrap();
                    parent.children.push(node.taxid); // add the node to the parent's child list 
                }   
            }

            hit_count += 1;
        }
    }
    Ok((hit_count, depth, root))
}
*/
#[frb(sync)]
pub fn fetch_hits(graph: HashMap<i64, Node>, root:i64) -> HitList{


    // Get all the hits under this node
    let mut hits: Vec<i64> = get_hits_from_tree(&graph, root);
    hits.sort(); 
    let hitlist = HitList{
        num_hits: hits.len() as i32,
        signature: graph[&root].name.clone(),
        hits: hits,
    };

  /*   let overview = ResultsOverview{
        num_hits: 0,
        num_categories: 0,
        categories: Vec::new(),
        domains_contained: Vec::new(),
    }; */
    hitlist
}

fn get_hits_from_tree(graph: &HashMap<i64, Node>, root: i64) -> Vec<i64>{
    let node = &graph[&root];  // assume a correct graph at this point
    let mut hits: Vec<i64> = node.hits.clone();
    let kids = node.children.clone();
    for child in kids{
        hits.append(&mut get_hits_from_tree(graph, child));
    };
    hits
}

fn create_domain_id_map(db: &fjall::PartitionHandle) -> Result<(HashMap<u16, Dmap>, HashMap<String, Dmap>), String>{
    let mut map:HashMap<u16, Dmap> = HashMap::new();
    let mut domain_info:HashMap<String, Dmap> = HashMap::new();
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
        domain_info.insert(ddata.name.clone(), ddata);
    }
   Ok((map, domain_info))
} 