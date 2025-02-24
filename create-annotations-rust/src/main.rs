use std::io::BufReader;
use std::fs::File;
use std::io::prelude::*;
use glob::glob;
use std::collections::HashMap;
use std::path::PathBuf;
use serde::{Serialize, Deserialize};
use fjall::{Config, PersistMode, PartitionCreateOptions};
use bincode;

#[derive(Serialize, Deserialize)]
struct Domain{
    domain: u16,  //numeric ID of the domain
    clan: u16, // numeric ID of the clan, FFFF if none 
    alifrom: u16, // Start of the hit to the domain
    alito: u16,  // End of the hit to the domain
    eval: f32 // evalue of the hit
}

fn parse_domtblout(domtblout: PathBuf, clan_map:&HashMap<String, (u16, u16)>, mut domains:HashMap<String, Vec<Domain>>)-> HashMap<String, Vec<Domain>>{
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
            let (did, cid) = match clan_map.get(dname){
                Some(vals) => vals,
                None => {
                    eprintln!("Domain {} not found in clan map", dname);
                    std::process::exit(1)
                }
            };
            let eval:f32 = fields[12].parse().expect("Error converting e-value to number");
            let alifrom:u16 = fields[17].parse().expect("Error converting alifrom to number");
            let alito:u16 = fields[18].parse().expect("Error converting alito to number");
            let dentry = Domain{
                domain: *did,
                clan: *cid,
                alifrom: alifrom,
                alito: alito,
                eval: eval,
            };

            if let Some(x) = domains.get_mut(&sequence){
                x.push(dentry)
            }
            else{
                domains.insert(sequence, vec!(dentry));
            }
        }

    }
    domains
}

fn remove_overlaps(mut domains:HashMap<String, Vec<Domain>>)-> HashMap<String, Vec<Domain>>{
    for (_, dlist) in domains.iter_mut(){
        let mut current = 0;
        let mut next = 1;
        while current < dlist.len(){
            while next < dlist.len(){
                if dlist[next].alifrom > dlist[current].alito{
                    // No overlap, stop checking this current and move on
                    next = dlist.len();
                }
                else{
                    // overlap
                    if (dlist[current].alito - dlist[next].alifrom < 5) ||
                       (dlist[current].clan != 0xffff && (dlist[current].clan == dlist[next].clan)){
                        // either small overlap or domains not in same clan, so shrink the one with the
                        // worse evalue
                        if dlist[current].eval < dlist[next].eval{
                            // Current has better eval, so shrink next
                            dlist[next].alifrom = dlist[current].alito +1;
                            if dlist[next].alito <= dlist[next].alifrom{
                                // next domain was shrunk out of existence, so remove it
                                dlist.remove(next);
                                // don't increment next, because everything slides down
                            }
                            else{
                                // next domain still exists, move on to the one after it
                                next +=1;
                            }
                        }
                        else{
                            // shrink current
                            dlist[current].alito = dlist[next].alifrom -1;
                            if dlist[current].alito <= dlist[current].alifrom{
                                // current domain was shrunk out of existence, remove it
                                dlist.remove(current);
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
                        if dlist[current].eval < dlist[next].eval{
                            // keep current
                            dlist.remove(next);
                            // don't change either current or next as next will have slid down
                        }
                        else{
                            dlist.remove(current);
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
    }
    domains
}

fn parse_clanfile(clanfile: PathBuf) -> HashMap<String, (u16, u16)>{
    let fp = match File::open(&clanfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", clanfile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut clan_map:HashMap<String, (u16, u16)> = HashMap::new();
    for family_result in freader.lines(){
        let fam = match family_result{
            Err(why) => panic!("Error reading line from {}: {}", clanfile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = fam.split('\t').collect();
        let fam_id:u16 = (&fields[0])[2..].parse().expect("Error converting family ID to number");
        let clan_id:u16;
        if fields[1].len() > 1{
            clan_id= (&fields[1])[2..].parse().expect("Error converting clan ID to number");
        }
        else{
            clan_id = 0xFFFF;
        }
        clan_map.insert(
            fields[3].to_string(),
            (fam_id, clan_id),
        );
    }

    clan_map
}


fn main() {
    let mut args = std::env::args().skip(1);
    if args.len() != 3{
        eprintln!("Usage: create_annotations <domtbldir> <clanfile> <outfile>");
        std::process::exit(1);
    }

    // extract arguments
    let mut dname = args.next().unwrap();
    let cfile = args.next().unwrap();
    let ofile = args.next().unwrap();


    // first, create a hashmap mapping domain names to IDs and clans 
    let clan_map:HashMap<String, (u16, u16)> = parse_clanfile(Into::into(cfile));
    
    // Create pattern to match all domtblout files in domtbldir
    if dname.chars().last().unwrap() == '/'{
        dname.push_str("*.domtblout");
    }
    else{
        dname.push_str("/*.domtblout");
    }
    
    
    let mut domains:HashMap<String, Vec<Domain>> = HashMap::new();

    // Go through the domtblouts and create hashmap of domains by sequence they hit
    for dfile in glob(&dname).expect("Couldn't find any domtbloutfiles in domtbldir"){
        match dfile{
            Ok(path) =>  domains = parse_domtblout(path, &clan_map, domains),
            Err(e) => {
                eprintln!("{:?}", e);
                std::process::exit(1);       
                    },
    
            }
    }
    
    //Handle overlapping hits
    domains = remove_overlaps(domains);

    //Write the results to a database
    let keyspace = Config::new(ofile).open().expect("Unable to create output database");
    let db = keyspace.open_partition("annotations", PartitionCreateOptions::default()).expect("Unable to create output partition");
    for key in domains.keys(){
        let dlist = domains.get(key).expect("Couldn't fetch a key that we know exists from HashMap");
        let encoded_domains: Vec<u8> = bincode::serialize(&dlist).expect("Failed to encode domains as vector of bytes");
        db.insert(key, &encoded_domains).expect("Failed to insert domain into output db");
    }
    keyspace.persist(PersistMode::SyncAll).expect("Failed to persist output db");

}
