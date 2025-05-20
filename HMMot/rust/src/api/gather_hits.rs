use std::io::BufReader;
use std::fs::File;
//use std::thread::sleep;
//use std::time;
use std::io::prelude::*;
use std::collections::HashMap;
use std::cmp::Reverse;
use serde::{Serialize, Deserialize};
use fjall::{Config, PartitionCreateOptions,UserValue, Slice, PartitionHandle};
use flutter_rust_bridge::frb;

#[derive(Clone)]
pub struct Domain{
    pub name: String,
    pub start: i32,
    pub end: i32,
    pub dom_evalue: f64,
    pub full_match_start: bool,
    pub full_match_end: bool,
  }

  #[derive(Clone)]
  pub struct Hit{
    pub name: String,  // Name of the sequence that the hit was to
    pub sequence: String,  // Sequence  that was hit
    pub seq_evalue: f64,
    pub structure_domains: Vec<Domain>,  // The (possibly-shortened) domains that make up the 
    // sequence's domain structure
    pub domains: Vec<Domain>,  // all of the domains that hit this sequence
    pub queries: Vec<Domain>,  // Queries that were hit
  }

  #[derive(Clone)]
  pub struct SigCategory{
    pub num_hits: i32,
    pub signature: String,
    pub example: Hit, 
  }

  #[derive(Clone)]
pub struct ResultsOverview{
    pub num_hits: i32,
    pub num_categories: i32,
    pub categories: Vec<SigCategory>,
    pub domains_contained: Vec<String>,
  }

#[derive(Clone)]
pub struct HitList{
    pub num_hits: i32,
    pub signature: String,
    pub hits: Vec<Hit>,
}

#[derive(Clone)]
pub struct SearchResults{
  pub succeeded: bool,
  pub err_msg: String,
  pub overview: ResultsOverview,
  pub hit_lists: Vec<HitList>,
}

#[derive(Serialize, Deserialize, Clone)]
struct DbDomain{
    domain: u16,  //numeric ID of the domain
    clan: u16, // numeric ID of the clan, FFFF if none 
    alifrom: u16, // Start of the hit to the domain
    alito: u16,  // End of the hit to the domain
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

#[derive(Serialize, Deserialize)]
struct AnnotatedSequence{
    name: String, 
    sequence: String,
    domains: Vec<DbDomain>,
    structure_domains: Vec<DbDomain>
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


#[derive(Clone, Serialize, Deserialize)]
struct Dmap{
    domain: u16,
    name: String,
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


// Generates a string representing the domain structure of a sequence
// Requires that the domains in its input vector are sorted in ascending 
// order by start position within the sequence
fn domains_to_structure(domains: &Vec<Domain>)->String{
    if domains.len() == 0{
        // sequence contained no standard domains
        return "None".to_string();
    }

    let mut structure = "".to_string();
    for domain in domains{
        if structure != ""{
            // There's already at least one domain in it
            structure.push_str(", ");
        }
        structure.push_str(&domain.name);
    }
    structure    

}

fn create_hitlists(sequences: HashMap<String, Hit>)->Vec<HitList>{
    //The input hashMap contains the set of hits found in the input domtblout files, indexed 
    // by the name of the sequence that the query hit.  
    // Transform that into a vector of HitLists, where the hits in each HitList have the same 
    // domain signature, in a two-phase process.  First, build a second HashMap where the keys are
    // strings representing domain signatures and the values are HitLists of hits that have that
    // domain signature.  Then, transform that into a vector of h(itLists, where each HitList is 
    // sorted in ascending order by e-value, and the vector is sorted by descending number of hits in each list

    // First, build the hashmap
    let mut hit_map:HashMap<String, HitList> = HashMap::new();
    for (_, hit) in sequences{
        let structure = domains_to_structure(&hit.structure_domains);
        match hit_map.get_mut(&structure){
            Some(prev_hits) => {
                prev_hits.num_hits+=1;
                prev_hits.hits.push(hit);
            },
            None=> {
                let new_hitlist = HitList{
                    num_hits: 1,
                    signature: structure.clone(),
                    hits: vec!(hit),
                };
                hit_map.insert(structure, new_hitlist);
            }
        }
    }

    //Now, transform into vector of HitLists
    let mut hit_lists = Vec::new();
    for (_, mut hit_list) in hit_map{
        hit_list.hits.sort_by(|a, b| a.seq_evalue.partial_cmp(&b.seq_evalue).unwrap_or(std::cmp::Ordering::Equal));
        hit_lists.push(hit_list);
    }
    // and sort the vector by descending number of hits in each list
    hit_lists.sort_by_key(|x| Reverse(x.num_hits));
    hit_lists
}



fn read_domtblout(mut sequences: HashMap<String, Hit>, clan_map: &HashMap<u16, String>, db: &PartitionHandle, 
    domtbloutfile: &String, eval_max: f64, dom_eval_max: f64)->Result<HashMap<String, Hit>, String>{
    let fp = match File::open(&domtbloutfile){
        Err(why) => return Err("Couldn't open ".to_string() + &domtbloutfile.to_string()+ &" for reading.  Reason was : ".to_string() + &why.to_string()),
        Ok(file) => file,
    };

    let freader = BufReader::new(fp);
    for hit_result in freader.lines(){
        let hit = match hit_result{
            Err(why) => return Err("Error reading line from ".to_string() +&domtbloutfile.to_string() + &". Reason was " + &why.to_string()),
            Ok(h) => h,
        };
        match hit.chars().next(){
            None => continue, // empty line, skip
            Some(c) => if c == '#'{
                // comment line, skip
                continue;
            },
        }

        let fields: Vec<&str> = hit.split_whitespace().collect();
        if fields.len() < 19{
            return Err("Error parsing domtblout file ".to_string() + &domtbloutfile.to_string() + &".  Not enough fields in line.  Line was: ".to_string() + &hit);
        }
        let sequence = fields[0].to_string();
        let d_name = fields[3];
        let d_eval:f64 = match fields[12].parse(){
            Err(_) => return Err("Error converting domain e-value field of ".to_string() + fields[12]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        let alifrom:i32 = match fields[17].parse(){
            Err(_) => return Err("Error converting alifrom field of ".to_string() + fields[17]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        let alito:i32 = match fields[18].parse(){
            Err(_) => return Err("Error converting alito field of ".to_string() + fields[18]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        let s_eval:f64 = match fields[6].parse(){
            Err(_) => return Err("Error converting sequence e-value field of ".to_string() + fields[6]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        let hmm_length:i32 = match fields[5].parse(){
            Err(_) => return Err("Error converting hmmlength field of ".to_string() + fields[5]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        let hmm_from:i32 = match fields[15].parse(){
            Err(_) => return Err("Error converting hmmfrom field of ".to_string() + fields[15]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        let hmm_to:i32 = match fields[16].parse(){
            Err(_) => return Err("Error converting hmmto field of ".to_string() + fields[16]+ &" to number.".to_string()),
            Ok(v) => v,
        };
        
        if  s_eval > eval_max || d_eval > dom_eval_max{
            // This hit doesn't meet our eval standards, ignore
            continue;
        } 

        // Create a Domain describing this hit
        let hit_domain = Domain{
            name: d_name.to_string(),
            start: alifrom,
            end: alito,
            dom_evalue: d_eval,
            full_match_start: (hmm_from == 1),
            full_match_end: (hmm_to == hmm_length),
        };

        if sequences.contains_key(&sequence){ // already have at least one hit to this sequence
            // so just add the new domain
            let existing_hit = sequences.get_mut(&sequence).unwrap();
            if s_eval < existing_hit.seq_evalue{ //This should only matter when we are merging results from
                // multiple searches
                existing_hit.seq_evalue = s_eval;
            }
            existing_hit.queries.push(hit_domain);
            
        }
        else{
            // Get the data for this sequence from the annotated db and build a new sequence
            let res1 = match db.get(&sequence){
                Err(why) => return Err("Error looking up sequence ".to_string() + &sequence + &" in annotations DB, reason was: ".to_string() + &why.to_string()),
                Ok(d) => d,
            };
            let seq_ann: AnnotatedSequence = match res1{
                Some(d) => match rmp_serde::from_slice(&d){
                    Ok(d) => d,
                    Err(msg) => return Err("Deserialization error for Annotated Sequence, reason was: ".to_string() + &msg.to_string()),
                },
                None => {return Err("Couldn't find sequence that we know exists in annotaitons DB".to_string());},
            };

            let mut our_domains = Vec::new();
            for db_domain in seq_ann.domains{
                let the_domain = Domain{
                    name: match clan_map.get(&db_domain.domain) {
                        None => return Err("Failed to find domain ".to_string() +&(db_domain.domain).to_string() +" in domain to clan map"),
                        Some(v) => v.clone(),
                    },
                    start: i32::from(db_domain.alifrom),
                    end: i32::from(db_domain.alito),
                    dom_evalue: f64::from(db_domain.eval),
                    full_match_start: db_domain.full_match_start, // These aren't relevant for domain annotations
                    full_match_end: db_domain.full_match_end,
                };
                our_domains.push(the_domain);
            }

            let mut structure_domains = Vec::new();
            for db_domain in seq_ann.structure_domains{
                let the_domain = Domain{
                    name: match clan_map.get(&db_domain.domain) {
                        None => return Err("Failed to find domain ".to_string() +&(db_domain.domain).to_string() +" in domain to clan map"),
                        Some(v) => v.clone(),
                    },
                    start: i32::from(db_domain.alifrom),
                    end: i32::from(db_domain.alito),
                    dom_evalue: f64::from(db_domain.eval),
                    full_match_start: db_domain.full_match_start, // These aren't relevant for domain annotations
                    full_match_end: db_domain.full_match_end,
                };
                structure_domains.push(the_domain);
            }
            let this_hit = Hit{
                name: sequence.clone(),  // Name of the sequence that the hit was to
                sequence: seq_ann.sequence,  // Sequence  that was hit
                seq_evalue: s_eval,
                domains: our_domains,
                structure_domains: structure_domains,
                queries: vec!(hit_domain),  // Queries that were hit
            };
            sequences.insert(sequence, this_hit);
        }
    }
    Ok(sequences)
}

// Creates a list, sorted in descending order by number of hits, of the domains that were found in the input
fn count_domains(hit_lists: &Vec<HitList>) -> Vec<String>{
    let mut domain_map:HashMap<String, i32> = HashMap::new();
    for hit_list in hit_lists{
        for hit in &hit_list.hits{
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
    }
    let mut domains:Vec<(String, i32)> = domain_map.into_iter().collect();
    domains.sort_by_key(|x| Reverse(x.1));
    let mut result = Vec::new();
    for (name, _) in domains{
        result.push(name);
    }
    result
}
// Top-level function to read search data results from domtblout files
// This is the ony one we want to expose on the Flutter side
#[frb(serialize)]
pub fn load_data(annfile: String, domtblout_files: Vec<String>, eval_max: f64, dom_eval_max: f64) -> SearchResults{
    // First, open the annotated sequence database and make sure it has the right stuff in it
    //sleep(time::Duration::from_secs(10));
    let overview = ResultsOverview{
        num_hits: 0,
        num_categories: 0,
        categories: Vec::new(),
        domains_contained: Vec::new(),
    };
    let mut results= SearchResults{
        succeeded: false,
        err_msg: "".to_string(),
        overview: overview,
        hit_lists: Vec::new(),
    };
    // open the annotations DB and make sure it has the partitions we expect
    let keyspace = match Config::new(&annfile).open(){
        Ok(v) => v,
        Err(msg) => {
            println!("Failed to open annotations database {}.  Error was {} ",annfile, &msg.to_string());
            results.err_msg = "Failed to open annotations database ".to_string() +&annfile +  &"Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };

    if !keyspace.partition_exists("annotations"){
        results.err_msg = "Couldn't find annotations data in database ".to_string() +&annfile;
        return results
    }

    if !keyspace.partition_exists("domainidtoname"){
        // we're overwriting an existing database, so delete the partition first
        results.err_msg = "Couldn't find domain ID to name data in database".to_string() +&annfile;
        return results
    }

    // Retrieve the clan ID->domain name mappings from the annotations DB
    let domain_db = match keyspace.open_partition("domainidtoname", PartitionCreateOptions::default()){
        Ok(v) => v,
        Err(msg) => {
            results.err_msg = "Failed to open domainidtoname partition, even though it exists.  Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };

    let clan_map:HashMap<u16, String> = match create_domain_id_map(&domain_db){
        Ok(v) => v,
        Err(msg) => {
            results.err_msg = "Couldn't create domain ID to name map from annotations database.  Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };

    // open the annotated sequence database
    let db = match keyspace.open_partition("annotations", PartitionCreateOptions::default()){
        Ok(v) =>v,
        Err(msg) => {
            results.err_msg = "Failed to open annotations partition, even though it exists.  Error was: ".to_string() + &msg.to_string();
            return results;
        },
    };
    
    let mut hit_sequences= HashMap::new();
    for domtbloutfile in domtblout_files{
        hit_sequences = match read_domtblout(hit_sequences, &clan_map, &db, &domtbloutfile, eval_max, dom_eval_max){
            Ok(v) => v,
            Err(msg) => {
                results.err_msg = "Error parsing domtblout file ".to_string() + &domtbloutfile+ "Error was: " + &msg.to_string();
                return results;
            },
        }
    }

    // Turn th ehashmap of hits into hitlists.  Has no failure cases
    results.hit_lists = create_hitlists(hit_sequences);

    // Gather the ranked list of domains found for coloring purposes in the GUI
    results.overview.domains_contained = count_domains (&results.hit_lists);
    // Now, build the overview structure
    let mut total_hits = 0;
    match i32::try_from(results.hit_lists.len()) {
        Ok(v) => results.overview.num_categories = v,
        Err(msg) => {
            results.succeeded = false;
            results.err_msg = msg.to_string();
            return results;
        }
    }
    for hit_list in &results.hit_lists{
        let new_category = SigCategory{
            num_hits: hit_list.num_hits,
            signature: hit_list.signature.clone(),
            example: hit_list.hits[0].clone(),
        };
        results.overview.categories.push(new_category);
        total_hits += hit_list.num_hits;
    }
    results.overview.num_hits = total_hits;

    // If we get this far, everyting has succeeded
    results.succeeded = true;
    results
}


fn create_domain_id_map(db: &fjall::PartitionHandle) -> Result<HashMap<u16, String>, String>{
    let mut map:HashMap<u16, String> = HashMap::new();

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

        map.insert(ddata.domain, ddata.name);
    }
    Ok(map)
}
//This was just a test function when developing, is not used in the actual app
//fn main() {
//    let mut args = std::env::args().skip(1);
//    if args.len() < 2{
//        eprintln!("Usage: group_hits <annotation_file> <domtblout files>");
//        std::process::exit(1);
//    }
//
//    let annfile = args.next().unwrap();
//    let mut domtbloutfiles:Vec<String> = Vec::new();
//
//    for file in args{
//        domtbloutfiles.push(file);
//    }
//
//    let results: SearchResults = load_data(annfile, domtbloutfiles);
//        // Next, open the annotations database 
//    if !results.succeeded{
//        println!("Failed with error message {}", results.err_msg);
//    }
//
//    for category in results.overview.categories{
//        println!("Found {} hits with domain architecture {}", category.num_hits, category.signature);
//    } 
//} 
