use std::io::BufReader;
use std::fs::File;
use std::io::prelude::*;
use std::collections::HashMap;
use std::path::PathBuf;
use serde::{Serialize, Deserialize};
use fjall::{UserValue, Slice};

#[derive(Clone)]
pub struct InterproInfo{
    pub id: String,
    pub ip_short: String,
    pub ip_long: String,
    pub pfam_name: String,
    pub i_type: IEntryType,
    pub description: String, 
}

impl InterproInfo{
    pub fn format(&self) -> String {
      format!("InterproInfo: id: {}, ip_short: {}, ip_long: {}, pfam_name: {}, description: {}", 
    self.id, self.ip_short, self.ip_long, self.pfam_name, self.description)
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct DomainInfo{
    pub name: String,
    pub description: String,
    pub length: u32, // Length of the domain in amino acids
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
pub struct Dmap{
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
    pub i_type: IEntryType,
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

// Enum that holds the source of the annotation data
#[derive(Clone, Serialize, Deserialize)]
pub enum AnnotationType{Hmmer, Interpro, Other}

impl From<&AnnotationType> for Slice{
    fn from(val: &AnnotationType) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for AnnotationType").into()
    }
}

impl From<&UserValue> for AnnotationType{
    fn from(value: &UserValue) -> Self{
        let item: AnnotationType = rmp_serde::from_slice(&value).expect("Deserialization error for AnnotationType");
        item
    }
}

// Enum that holds the type of entry for an Interpro Annotation
#[derive(Clone, Serialize, Deserialize)]
pub enum IEntryType{Superfamily, Family, Domain, Repeat, Site, Other}

impl From<&IEntryType> for Slice{
    fn from(val: &IEntryType) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for IEntryType").into()
    }
}

impl From<&UserValue> for IEntryType{
    fn from(value: &UserValue) -> Self{
        let item: IEntryType = rmp_serde::from_slice(&value).expect("Deserialization error for IEntryType");
        item
    }
}


#[derive(Clone, Serialize, Deserialize)]
pub struct Domain{
    pub domain: u32,  //numeric ID of the domain
    pub clan: u32, // numeric ID of the clan, FFFF if none 
    pub alifrom: u32, // Start of the hit to the domain
    pub alito: u32,  // End of the hit to the domain
    pub hmmfrom: u32, // Start of the HMM match
    pub hmmto: u32, // End of the HMM match
    pub eval: f32, // evalue of the hit
    pub full_match_start: bool,  // Was the domain a full match to the start of HMM
    pub full_match_end: bool,  // and/or the end
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
pub struct AnnotatedSequence{
    pub name: String, 
    pub sequence: String,
    pub length: u32,
    pub taxid: i64,
    pub domains: Vec<Domain>,
    pub structure_domains: Vec<Domain>,
    pub real: bool,
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

#[derive(Serialize, Deserialize, Clone)]
pub struct Node{
    pub taxid: i64,
    pub parent: i64,
    pub children: Vec<i64>,
    pub rank: String,
    pub ranknum: u32,
    pub name: String,
    pub hits_below: i64,
    pub hits: Vec<i64>,  // We don't use this, hope that an empty vector is the same size as an empty vec<Hit>
    pub my_arc_start: f64, // Not used on the Rust side, but useful for Flutter visualization
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


// Read in a names.dmp file from NCBI and create a mapping from taxid to scientific name
pub fn read_names_dmp(namfile: PathBuf) -> HashMap<i64, String>{
    let fp = match File::open(&namfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", namfile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut name_map:HashMap<i64, String> = HashMap::new();
    for name_result in freader.lines(){  
        let line = match name_result{
            Err(why) => panic!("Error reading line from {}: {}", namfile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = line.split('|').map(|s| s.trim()).collect();
        if fields.len() < 4{
            continue; // skip malformed lines
        }
        if fields[3] == "scientific name"{
            let taxid:i64 = fields[0].parse().expect("Error converting taxid to number");
            let name = fields[1].to_string();
            name_map.insert(taxid, name);
        }
    }
    name_map
}

// Read in a merged.dmp file and create a mapping from old->new id
pub fn read_merged_dmp(mergefile: PathBuf) -> HashMap<i64, i64>{
    let fp = match File::open(&mergefile){
        Err(why) => panic!("Couldn't open {} for reading: {}", mergefile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut merge_map:HashMap<i64, i64> = HashMap::new();
    for name_result in freader.lines(){  
        let line = match name_result{
            Err(why) => panic!("Error reading line from {}: {}", mergefile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = line.split('|').map(|s| s.trim()).collect();
        if fields.len() < 2{
            continue; // skip malformed lines
        }
        let oldid:i64 = fields[0].parse().expect("Error converting oldid to number in read_merged_dmp");
        let newid = fields[1].parse().expect("Error converting newid to number in read_merged_dmp");
        merge_map.insert(oldid, newid);
        
    }
    merge_map
}



// reads a file containing mappings from old->new taxids for 
// nodes that have been compressed out of the taxonomy.
pub fn read_deleted(subfile: PathBuf) -> HashMap<i64, i64>{
    let fp = match File::open(&subfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", subfile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut sub_map:HashMap<i64, i64> = HashMap::new();
    for line_result in freader.lines(){
        let line = match line_result{
            Err(why) => panic!("Error reading line from {}: {}", subfile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() < 2{
            continue; // skip malformed lines
        }
        let old:i64 = fields[0].parse().expect("Error converting deleted taxid to number");
        sub_map.insert(old, old);
    }

    sub_map
}

// Read an NCBI nodes.dmp file and create a graph from it.  
// The graph is implemented as a HashMap from taxid to Node struct,
// where node 1 is the root of the tree.
pub fn read_nodes_dmp(nodesfile: PathBuf, name_map: &HashMap<i64, String>) -> HashMap<i64, Node>{
    // First, read through the file and create a node object for each taxid
    let fp = match File::open(&nodesfile){
        Err(why) => panic!("Couldn't open {} for reading: {}", nodesfile.display(), why),
        Ok(file) => file,
    };
    let freader = BufReader::new(fp);
    let mut node_map:HashMap<i64, Node> = HashMap::new();
    for node_result in freader.lines(){  
        let line = match node_result{  
            Err(why) => panic!("Error reading line from {}: {}", nodesfile.display(), why),
            Ok(h) => h,
        };
        let fields: Vec<&str> = line.split('|').map(|s| s.trim()).collect();
        let taxid:i64 = fields[0].parse().expect("Error converting taxid to number");
        let parent:i64 = fields[1].parse().expect("Error converting parent taxid to number");
        let rank = fields[2].to_string();
        let ranknum:u32;
        ranknum = match rank.as_str(){
            "no rank" => 0,
            "domain" => 1,
            "cellular root" => 1,
            "acellular root" => 1,      
            "realm" => 1,
            "kingdom" => 2,
            "subkingdom" => 3,
            "superphylum" => 4,
            "phylum" => 5,
            "subphylum" => 6,   
            "superclass" => 7,
            "class" => 8,
            "subclass" => 9,
            "infraclass" => 10,
            "cohort" => 11,
            "subcohort" => 12,
            "superorder" => 13,
            "order" => 14,
            "suborder" => 15,    
            "infraorder" => 16,
            "parvorder" => 17,
            "superfamily" => 18,
            "family" => 19,
            "subfamily" => 20,
            "genus" => 21,
            "subgenus" => 22,
            "section" => 23,
            "subsection" => 23,
            "species group" => 24,
            "series" => 24,
            "species subgroup" => 25,
            "species" => 26,
            "strain" => 27,
            "serotype" => 27,
            "isolate" => 27,
            "subspecies" => 27,
            "forma specialis"   => 27,
            "serogroup" => 27,
            "tribe" => 28,
            "subtribe" => 29,
            "forma" => 30,
            "morph" => 30,
            "variety" => 31,
            "varietas" => 31,
            "subvariety" => 32,
            "pathogroup" => 33,
            "biotype" => 33,
            "clade" => 34,
            "genotype" => 34,
            _ => 100, // other ranks
        };
    
        if ranknum == 100{
            eprintln!("Warning: Unrecognized rank {} for taxid {}", rank, taxid);
        }
        let name = match name_map.get(&(taxid as i64)){
            Some(n) => n.clone(),
            None => {eprintln!("No name found for taxid {}, using taxid as name", taxid); taxid.to_string()},
        };
        let node = Node{
            taxid: taxid,
            parent: parent,
            children: Vec::new(),
            rank: rank,
            ranknum: ranknum,
            name: name,
            hits_below: 0,
            hits: Vec::new(),
            my_arc_start: 0.0,
            my_arc_end: 0.0,    
        };
        node_map.insert(taxid, node);
    }
    // Now, go through and create the parent->child edge list.  
    // need to create edges in two passes because of borrow rules
    let mut edges: Vec<(i64, i64)> = Vec::new();
    for (taxid, node) in node_map.iter(){
        let parent = node.parent;
        if parent != *taxid{ // skip root node
            edges.push((parent, *taxid));
        }
    }
    for (parent, child) in edges{
        if let Some(parent_node) = node_map.get_mut(&parent){
            parent_node.children.push(child);
        }
        else{
            eprintln!("Warning: Parent taxid {} not found when adding child {}", parent, child);
        }
    }
    //println!("Read {} nodes from {}", node_map.len(), nodesfile.display());
    //println!("Root node is taxid 1 with {} children", node_map.get(&  
    node_map
}

    // Compresses the NCBI taxonomy by removing nodes with non-canonical ranks
pub fn compress_taxonomy(full_tree: HashMap<i64, Node>) -> (HashMap<i64, Node>, HashMap<i64, i64>){
    let always_compress:Vec<i64> = vec![131567, 2787823, 2787854];  // cellular organisms, unclassified, other

    // create HashMap mapping all ranknums to their canonical ranks (compressing upward)
    let mut ranknum_to_canonical: HashMap<u32, (u32, String)> = HashMap::new();
    ranknum_to_canonical.insert(0, (0, "no rank".to_string()));
    ranknum_to_canonical.insert(1, (1, "domain".to_string()));
    ranknum_to_canonical.insert(2, (2, "kingdom".to_string()));
    ranknum_to_canonical.insert(3, (2, "kingdom".to_string()));
    ranknum_to_canonical.insert(4, (2, "kingdom".to_string()));
    ranknum_to_canonical.insert(5, (3, "phylum".to_string()));
    ranknum_to_canonical.insert(6, (3, "phylum".to_string()));
    ranknum_to_canonical.insert(7, (3, "phylum".to_string()));
    ranknum_to_canonical.insert(8, (4, "class".to_string()));
    ranknum_to_canonical.insert(9, (4, "class".to_string()));
    ranknum_to_canonical.insert(10, (4, "class".to_string()));
    ranknum_to_canonical.insert(11, (4, "class".to_string()));
    ranknum_to_canonical.insert(12, (4, "class".to_string()));
    ranknum_to_canonical.insert(13, (4, "class".to_string()));
    ranknum_to_canonical.insert(14, (5, "order".to_string()));
    ranknum_to_canonical.insert(15, (5, "order".to_string()));
    ranknum_to_canonical.insert(16, (5, "order".to_string()));
    ranknum_to_canonical.insert(17, (5, "order".to_string()));
    ranknum_to_canonical.insert(18, (5, "order".to_string()));
    ranknum_to_canonical.insert(19, (6, "family".to_string()));
    ranknum_to_canonical.insert(20, (6, "family".to_string()));
    ranknum_to_canonical.insert(21, (7, "genus".to_string()));
    ranknum_to_canonical.insert(22, (7, "genus".to_string()));
    ranknum_to_canonical.insert(23, (7, "genus".to_string()));
    ranknum_to_canonical.insert(24, (7, "genus".to_string()));
    ranknum_to_canonical.insert(25, (7, "genus".to_string()));
    ranknum_to_canonical.insert(26, (8, "species".to_string()));
    ranknum_to_canonical.insert(27, (8, "species".to_string()));
    ranknum_to_canonical.insert(28, (8, "species".to_string()));
    ranknum_to_canonical.insert(29, (8, "species".to_string()));
    ranknum_to_canonical.insert(30, (8, "species".to_string()));
    ranknum_to_canonical.insert(31, (8, "species".to_string()));
    ranknum_to_canonical.insert(32, (8, "species".to_string()));
    ranknum_to_canonical.insert(33, (8, "species".to_string()));
    ranknum_to_canonical.insert(34, (8, "species".to_string()));

    
  
    let mut compressed_tree: HashMap<i64, Node> = HashMap::new();
    let canonical_ranks: Vec<u32> = vec![1,2,5,8,14,19,21,26]; // domain, kingdom, phylum, class, order, family, genus, species
    let mut keep: Vec<(Node, bool)> = Vec::new();
    let mut compress_out: Vec<(Node, bool)> = vec![];
    let mut compressed:i64 = 0;
    let mut old_to_new: HashMap<i64, i64> = HashMap::new(); // map from old taxid to new taxid (if compressed out)

    let mut root = full_tree.get(&1).unwrap().clone();
    if root.name == "Orthagio p. Whackitude"{ // This is stupid, but should silence compiler warnings about never reading the name field.
        print!("really wierd taxon name found")
    }
    (root.ranknum, root.rank) = ranknum_to_canonical.get(&root.ranknum).unwrap().clone(); // reassign root to canonical rank
    keep.push((root, false));    
    let mut max_ranknum = 0;
    while !keep.is_empty(){
        let mut parent:Node;
        let force_compressed: bool;
        (parent, force_compressed) = keep.pop().unwrap();
        let parent_children = parent.children;  
        parent.children = vec![]; // clear out the children so we can add the ones we want to keep.
       // let parent_rank = parent.ranknum;

        // Figure out which of the parent's children we should keep
        for child_id in parent_children.iter(){
            if let Some(child) = full_tree.get(child_id){
               /*  if always_compress.contains(child_id){
                    println!("force-compressing ID {}", child_id);
                }*/
                if canonical_ranks.contains(&child.ranknum) && !always_compress.contains(child_id){
                    // This child is a canonical rank, so keep it
                    let mut new_child = child.clone();
                    (new_child.ranknum, new_child.rank) = ranknum_to_canonical.get(&child.ranknum).unwrap().clone(); // reassign to canonical rank
                    if !force_compressed{ // need to adjust ranknum because node has two ancestors with same rank 
                        new_child.ranknum +=1;
                        new_child.rank = new_child.rank + "+";
                     //   println!("Incrementing ranknum of {} to {}", new_child.name, new_child.ranknum);
                    }
                    new_child.parent = parent.taxid; // reassign parent to the new parent
                    parent.children.push(new_child.taxid);
                    keep.push((new_child, force_compressed));
                }
                else{ // Child has rank between parent and next canonical rank, so compress it out
                    compress_out.push((child.clone(), force_compressed || always_compress.contains(child_id)));
                    compressed += 1;
                }
            }
            else{
                eprintln!("Warning: Child taxid {} not found in full tree", child_id);
            }
        }

        // compress out all descendant nodes with ranks between parent and next canonical rank
        //let mut to_process = compress_out.clone();
        //compress_out.clear();
        while !compress_out.is_empty(){
            let (node, force_compressed) = compress_out.pop().unwrap();
            old_to_new.insert(node.taxid, parent.taxid); // map old taxid to new parent taxid
            for child_id in node.children.iter(){
                if let Some(child) = full_tree.get(child_id){
                    if canonical_ranks.contains(&child.ranknum) && !always_compress.contains(&child.taxid) {
                        // This child is the next canonical rank, and not a node we always compress out so keep it
                        let mut child_clone = child.clone();
                        child_clone.parent = parent.taxid; // reassign parent to the next cannonical parent
                        (child_clone.ranknum, child_clone.rank) = ranknum_to_canonical.get(&child.ranknum).unwrap().clone(); // reassign to canonical rank
                    if !force_compressed{ // need to adjust ranknum because node has two ancestors with same rank 
                        child_clone.ranknum +=1;
                        child_clone.rank = child_clone.rank+"+";
                    //    println!("incrementing ranknum of {} to {}", child_clone.name, child_clone.ranknum);
                    }
                        parent.children.push(child_clone.taxid);
                        keep.push((child_clone, force_compressed ));
                    }
                    else{
                        // This child is still between canonical ranks, so keep compressing
                        compress_out.push((child.clone(), force_compressed || always_compress.contains(&child.taxid))); 
                        compressed += 1;
                    }
                }
                else{
                    eprintln!("Warning: Child taxid {} not found in full tree", child_id);
                }
            }
        }
        if parent.ranknum > max_ranknum{
            max_ranknum = parent.ranknum;
        }
        compressed_tree.insert(parent.taxid, parent);
    }
    println!("original graph had {} nodes, compressed out {} nodes, compressed graph has {} nodes", 
        full_tree.len(), compressed, compressed_tree.len());
    if compressed_tree.len() + compressed as usize != full_tree.len(){
        eprintln!("Warning: Node count mismatch after compression");
    }
    if old_to_new.len() != compressed as usize{
        eprintln!("Warning: Old to new mapping size mismatch after compression");
    }
    println!("Max ranknum in compressed tree is {}", max_ranknum);
    (compressed_tree, old_to_new)
}


pub fn saturating_add(a: u32, b: u32) -> u32 {
    a.checked_add(b).unwrap_or(u32::MAX)
}
pub fn saturating_sub(a: u32, b: u32) -> u32 {
    a.checked_sub(b).unwrap_or(0)
}