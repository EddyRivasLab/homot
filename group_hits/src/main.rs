
use std::io::BufReader;
use std::fs::File;
use std::io::prelude::*;
use glob::glob;
use std::collections::HashMap;
use std::path::PathBuf;
use serde::{Serialize, Deserialize};
use fjall::{Config, PartitionCreateOptions};
use bincode;

#[derive(Serialize, Deserialize)]
struct Domain{
    domain: u16,  //numeric ID of the domain
    clan: u16, // numeric ID of the clan, FFFF if none 
    alifrom: u16, // Start of the hit to the domain
    alito: u16,  // End of the hit to the domain
    eval: f32 // evalue of the hit
}

impl Domain{

    // Generates a string that describes a domaing
    fn make_string(&self, clan_map: &HashMap<u16, String>) -> String{
        // this has non-canonical name because it needs a second argument that to_String() does not

        // Get the domain name
        let mut ret_string:String = clan_map.get(&self.domain).expect("Unable to find family in clan_map in make_String").clone();

        ret_string.push_str(", ");
        ret_string.push_str(&(self.alifrom.to_string()));
        ret_string.push_str(", ");
        ret_string.push_str(&(self.alito.to_string()));
        ret_string
    }
}


// Iterates through the domains in a vector, converting each one to a string representation
fn dlist_to_string(dlist: &Vec<Domain>, clan_map: &HashMap<u16, String>)->String{
    let mut ret_string:String = String::new();
    for domain in dlist.iter(){
        if !ret_string.is_empty(){
            ret_string.push_str(", ");
        }
        ret_string.push_str(&(domain.make_string(clan_map)));
    }
    ret_string
}

// Debugging routine that prints out the domain signatures of the sequences that hit in a domtable
fn print_domtable_domains(dtable: PathBuf, clan_map: &HashMap<u16, String>, db: &fjall::PartitionHandle){
    let fp = match File::open(&dtable){
        Err(why) => panic!("Couldn't open {} for reading: {}", dtable.display(), why),
        Ok(file) => file,
    };

    let freader = BufReader::new(fp);
    for hit_result in freader.lines(){
        let hit = match hit_result{
            Err(why) => panic!("Error reading line from {}: {}", dtable.display(), why),
            Ok(h) => h,
        };
        if hit.chars().next().unwrap() == '#'{
            // comment line, skip
            continue;
        }
        else{
            let fields: Vec<&str> = hit.split_whitespace().collect();
            let mut sequence = fields[0].to_string();
            let dsoption = match db.get(&sequence){
                Err(why) => panic!("Error looking up sequence {} in annotations DB, reason was {}", &sequence, why),
                Ok(d) => d
            };
            sequence.push_str(" ");  // Do this here because otherwise all the db lookups fail
            match dsoption{ // Was there a domain signature for the sequence in the DB
                // Might not be, many sequences don't have known domains 
                Some(dt) => {let dlist:Vec<Domain> = bincode::deserialize(&dt).expect("Failed to deserialize domain list");
                sequence.push_str(&dlist_to_string(&dlist, clan_map));
                },
                None => sequence.push_str("None")
            };
            
            println!("{}", &sequence); 
        }
    }
}

fn create_domain_id_map(db: &fjall::PartitionHandle) -> HashMap)<u16, String>{
    let mut map:HashMap<u16, String> = HashMap::new();

    for key in db.keys(){ // This would be dangerous if we didn't know that the domainidtoname partition didn't 
    // have a limited number of entries
        let res1 = match db.get(key){
            Err(why) => panic!("Error looking up domain {} in annotations DB, reason was {}", &key, why),
            Ok(d) => d
        };
        let dname = match res1{
            Some(d) => d,
            None => panic!("Couldn't find domain that we know exists in annotaitons DB");

        }
        map.insert(key.parse(), dname);
    }
    map
}

fn main() {
    let mut args = std::env::args().skip(1);
    if args.len() != 2{
        eprintln!("Usage: group_hits <domtbldir> <annotation_file>");
        std::process::exit(1);
    }

    let mut dname = args.next().unwrap();
    let annfile = args.next().unwrap();

    // Next, open the annotations database 
    let keyspace = Config::new(&annfile).open().expect("Unable to open annotation database");
    if !keyspace.partition_exists("annotations"){
        // we're overwriting an existing database, so delete the partition first
        eprintln!("Couldn't find annotations data in database {},", annfile);
        std::process::exit(1);
    }

    // Retrieve the clan ID->domain name mappings from the annotations DB
    let domain_db = keyspace.open_partition("domainidtoname", PartitionCreateOptions::default()).expect("Unable to open domain id data, although we know it exists.");
    let clan_map:HashMap<u16, String> = create_domain_id_map(domain_db);

    let db = keyspace.open_partition("annotations", PartitionCreateOptions::default()).expect("Unable to open annotations data, although we know it exists.");

     // Create pattern to match all domtblout files in domtbldir
    if dname.chars().last().unwrap() == '/'{
        dname.push_str("*.domtblout");
    }
    else{
        dname.push_str("/*.domtblout");
    }
    
    // Go through the domtblouts and create hashmap of domains by sequence they hit
    for dfile in glob(&dname).expect("Couldn't find any domtbloutfiles in domtbldir"){
        match dfile{
            Ok(path) =>  print_domtable_domains(path, &clan_map, &db),
            Err(e) => {
                eprintln!("{:?}", e);
                std::process::exit(1);       
            },
        
        }
    }
        
}
