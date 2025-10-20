use std::collections::HashMap;
use std::io::BufReader;
use std::fs::File;
use std::path::PathBuf;
use std::io::prelude::*;
#[derive(Clone)]
struct Node{
    taxid: i64,
    parent: i64,
    children: Vec<i64>,
    rank: String,
    ranknum: u32,
    name: String,
}
fn main() {
    // handle arguments
    let mut args = std::env::args().skip(1);
    if args.len() != 4 {
        eprintln!("Usage: compress_ncbi_taxonmy <nodes.dmp> <names.dmp> <output nodes.dmp> <compressed->new mapping file>.");
        std::process::exit(1);
    }
    let nodesfile = args.next().unwrap();
    let namesfile = args.next().unwrap();
    let outnodesfile = args.next().unwrap();
    let mappingfile = args.next().unwrap();

    // Read and parse the NCBI taxonomy files
    let name_map = read_names_dmp(namesfile.into());
    let node_map = read_nodes_dmp(nodesfile.into(), &name_map);
    check_graph(&node_map);

    print!("Compressing taxonomy...\n");
    let (compressed_map, new_taxids) = compress_taxonomy(node_map);
    check_graph(&compressed_map);
    write_compressed_graph(&compressed_map, outnodesfile.into());
    write_mapping(&new_taxids, mappingfile.into());
}

fn write_compressed_graph(graph: &HashMap<i64, Node>, outnodesfile: PathBuf){
    let mut outfp = match File::create(&outnodesfile){
        Err(why) => panic!("Couldn't open {} for writing: {}", outnodesfile.display(), why),
        Ok(file) => file,
    };

    let mut keys = graph.keys().cloned().collect::<Vec<i64>>();
    keys.sort();
    for taxid in keys{
        let node = graph.get(&taxid).unwrap();  
        let line = format!("{}\t|\t{}\t|\t{}\t|\n", taxid, node.parent, node.rank);
        if let Err(why) = outfp.write_all(line.as_bytes()){
            eprintln!("Error writing to {}: {}", outnodesfile.display(), why);
        }
    }
    println!("Wrote compressed graph with {} nodes to {}", graph.len(), outnodesfile.display());
}

fn write_mapping(mapping: &HashMap<i64, i64>, mappingfile: PathBuf){
    let mut outfp = match File::create(&mappingfile){
        Err(why) => panic!("Couldn't open {} for writing: {}", mappingfile.display(), why),
        Ok(file) => file,
    };
    for (old_taxid, new_taxid) in mapping.iter(){
        let line = format!("{}\t{}\n", old_taxid, new_taxid);
        if let Err(why) = outfp.write_all(line.as_bytes()){
            eprintln!("Error writing to {}: {}", mappingfile.display(), why);
        }
    }
    println!("Wrote mapping of {} compressed taxids to {}", mapping.len(), mappingfile.display());
}

fn check_graph(graph: &HashMap<i64, Node>){
    let found_count = count_findable(graph, 1);
    if found_count != graph.len() as i64{
        eprintln!("Warning: Only found {} of {} nodes starting from root", found_count, graph.len());
    }
    else{
        println!("All {} nodes reachable from root", graph.len());
    }
    if check_links(graph, 1){
        println!("All parent-child links are consistent");
    }
    else{
        eprintln!("Warning: Some parent-child links are inconsistent");
    }
}

fn check_links(graph: &HashMap<i64, Node>, start: i64) -> bool{
    if let Some(node) = graph.get(&start){
        for child in node.children.iter(){
            if let Some(child_node) = graph.get(child){
                if child_node.parent != start{
                    eprintln!("Inconsistent link: parent {} has child {}, but child {} has parent {}", start, child, child, child_node.parent);
                    return false;
                }
            }
            else{
                eprintln!("Child node {} not found in graph", child);
                return false;
            }
            if !check_links(graph, *child){
                return false;
            }
        }
    }
    true
}

fn count_findable(graph: &HashMap<i64, Node>, start: i64) -> i64{
    let mut count = 0;
    if let Some(node) = graph.get(&start){
        count += 1; // count this node
        for child in node.children.iter(){
            count += count_findable(graph, *child);
        }
    }
    count
}

fn compress_taxonomy(full_tree: HashMap<i64, Node>) -> (HashMap<i64, Node>, HashMap<i64, i64>){

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
    ranknum_to_canonical.insert(23, (7, "genus".to_string  ()));
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
    let mut keep: Vec<Node> = Vec::new();
    let mut compress_out: Vec<Node> = vec![];
    let mut compressed:i64 = 0;
    let mut old_to_new: HashMap<i64, i64> = HashMap::new(); // map from old taxid to new taxid (if compressed out)

    let mut root = full_tree.get(&1).unwrap().clone();
    (root.ranknum, root.rank) = ranknum_to_canonical.get(&root.ranknum).unwrap().clone(); // reassign root to canonical rank
    keep.push(root);    
    let mut max_ranknum = 0;
    while !keep.is_empty(){
        let mut parent = keep.pop().unwrap();
        let parent_children = parent.children;  
        parent.children = vec![]; // clear out the children so we can add the ones we want to keep.
        let parent_rank = parent.ranknum;

        // Figure out which of the parent's children we should keep
        for child_id in parent_children.iter(){
            if let Some(child) = full_tree.get(child_id){
                if child.ranknum < parent_rank && child.ranknum != 0{
                    // This should never happen, but just in case
                    eprintln!("Warning: Child rank {} is less than parent rank {} for parent {} ({}) and child {} ({})", 
                            child.ranknum, parent_rank, parent.taxid, parent.rank, child.taxid, child.rank);
                    continue;
                }
                if canonical_ranks.contains(&child.ranknum){
                    // This child is a canonical rank, so keep it
                    let mut new_child = child.clone();
                    (new_child.ranknum, new_child.rank) = ranknum_to_canonical.get(&child.ranknum).unwrap().clone(); // reassign to canonical rank
                    new_child.parent = parent.taxid; // reassign parent to the new parent
                    parent.children.push(new_child.taxid);
                    keep.push(new_child);
                }
                else{ // Child has rank between parent and next canonical rank, so compress it out
                    compress_out.push(child.clone());
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
            let node = compress_out.pop().unwrap();
            old_to_new.insert(node.taxid, parent.taxid); // map old taxid to new parent taxid
            for child_id in node.children.iter(){
                if let Some(child) = full_tree.get(child_id){
                    if child.ranknum < parent_rank && child.ranknum != 0{
                        // This should never happen, but just in case
                        eprintln!("Warning: Child rank {} is less than parent rank {} for parent {} ({}) and child {} ({})", 
                            child.ranknum, parent_rank, parent.taxid, parent.rank, child.taxid, child.rank);
                        continue;
                    }
                    if canonical_ranks.contains(&child.ranknum){
                        // This child is the next canonical rank, so keep it
                        let mut child_clone = child.clone();
                        child_clone.parent = parent.taxid; // reassign parent to the next cannonical parent
                        (child_clone.ranknum, child_clone.rank) = ranknum_to_canonical.get(&child.ranknum).unwrap().clone(); // reassign to canonical rank
                        parent.children.push(child_clone.taxid);
                       
                        keep.push(child_clone);
                    }
                    else{
                        // This child is still between canonical ranks, so keep compressing
                        compress_out.push(child.clone()); 
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

// Read an NCBI nodes.dmp file and create a graph from it.  
// The graph is implemented as a HashMap from taxid to Node struct,
// where node 1 is the root of the tree.
fn read_nodes_dmp(nodesfile: PathBuf, name_map: &HashMap<i64, String>) -> HashMap<i64, Node>{
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
        let ranknum:u32 = match rank.as_str(){
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
    println!("Read {} nodes from {}", node_map.len(), nodesfile.display());

    node_map
}

// Read in a names.dmp file from NCBI and create a mapping from taxid to scientific name
fn read_names_dmp(namfile: PathBuf) -> HashMap<i64, String>{
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
