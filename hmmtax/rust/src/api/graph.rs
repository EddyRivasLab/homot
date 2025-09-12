use flutter_rust_bridge::frb;
use serde::{Serialize, Deserialize};
use fjall::{Config, PartitionCreateOptions,UserValue, Slice};
use core::panic;
use std::{collections::HashMap};
use rand::prelude::*;
#[derive(Serialize, Deserialize, Clone)]
#[frb(non_final)]
pub struct Node{
    pub taxid: i64,
    pub parent: i64,
    pub children: Vec<i64>,
    pub rank: String,
    pub ranknum: u32,
    pub name: String,
    pub total_descendants: i64,
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
pub struct SearchResults{
    pub succeeded: bool,
    pub message: String,
    pub depth: u32,
    pub root: i64,
    pub graph: HashMap<i64, Node>,
}
impl From<&SearchResults> for Slice{
    fn from(val: &SearchResults) ->Self{
        rmp_serde::to_vec(&val).expect("Serialization error for Node").into()
    }
}
impl From<&UserValue> for SearchResults{
    fn from(value: &UserValue) -> Self{
        let item: SearchResults = rmp_serde::from_slice(&value).expect("Deserialization error for Node");
        item
    }
}


pub fn count_descendants(graph: &mut HashMap<i64, Node>, id: i64) -> i64 {
    let mut total: i64 = 0;   
    let children: Vec<i64>;
    if let Some(node) = graph.get(&id) {
        children = node.children.clone();

    } else {
        panic!("Node with taxid {} not found in graph", id);
    }

    for child_id in children {
        total += 1 + count_descendants(graph, child_id as i64);
    }
    if let Some(node) = graph.get_mut(&id) {
        node.total_descendants = total;
    }
    else{
        panic!("Node with taxid {} not found in graph", id);
    }
    total
}

fn add_children(mut graph: HashMap<i64, Node>, parent_id: i64, current_level: u32, max_levels: u32, max_children: u32, next_id: i64) -> (i64, HashMap<i64, Node>) {
    if current_level >= max_levels {
        return (next_id, graph);
    }

    let mut rng = rand::rng();
    let num_children = rng.random_range(1..=max_children) as u64;
    let mut children_ids: Vec<i64> = Vec::new();
    
    let mut new_next = next_id;
    for _ in 0..num_children {
        let child_id = new_next;
        new_next += 1;
        children_ids.push(child_id);
        let child_node = Node {
            taxid: child_id,
            parent: parent_id,
            children: Vec::new(),
            rank: format!("rank_{}", current_level + 1),
            ranknum: current_level + 1,
            name: format!("Node_{}", child_id),
            total_descendants: 0,
            my_arc_start: 0.0,
            my_arc_end: 0.0,
        };
        graph.insert(child_id as i64, child_node);
        (new_next, graph) = add_children(graph, child_id,  current_level + 1, max_levels, max_children, new_next);
    }
    graph.get_mut(&(parent_id as i64)).unwrap().children = children_ids;

    return (new_next, graph);
}

#[frb(serialize)]
#[frb(sync)]
pub fn create_graph(num_levels:u32, max_children:u32)-> SearchResults{
    let mut graph: HashMap<i64, Node> = HashMap::new();
    let root = Node {
        taxid: 0,
        parent: 0,
        children: vec![1, 2],
        rank: "root".to_string(),
        ranknum: 0,
        name: "Root".to_string(),
        total_descendants: 0,
        my_arc_start: 0.0,
        my_arc_end: 0.0,
    };
    graph.insert(0, root);
    let (_next_id,graph) = add_children(graph, 0, 0, num_levels, max_children, 1);
    let mut graph = graph;
    
    count_descendants(&mut graph, 0);
    let result = SearchResults{
        succeeded: true,
        message: format!("Graph with {} nodes created", graph.len()),
        depth: num_levels,
        root: 0,
        graph: graph,
    };
    result

}

#[frb(serialize)]
#[frb(sync)]
pub fn fetch_graph(database_path: String) -> HashMap<i64, Node> {
    let db_config = Config::new(&database_path);
    
    let keyspace = match db_config.open() {
        Ok(ks) => ks,
        Err(e) => panic!("Could not open keyspace: {}", e),
    };

    let mut graph: HashMap<i64, Node> = HashMap::new();
    let partition = keyspace.open_partition("nodes", PartitionCreateOptions::default()).expect("Could not open partition 'nodes'");
    for key in partition.keys(){
        let keybody: Slice = match key{
            Ok(k) => k,
            Err(e) => {
                eprintln!("Error retrieving key: {}", e);
                continue;
            }
        };
        let res1 = match partition.get(&keybody){
            Ok(v) => v,
            Err(e) => {
                eprintln!("Error retrieving value for key {:?}: {}", keybody, e);
                continue;
            }
        };
        let node: Node = match res1{
            Some(v) => match rmp_serde::from_slice(&v){
                Ok(n) => n,
                Err(e) =>{
                    eprintln!("Deserialization error for key {:?}: {}", keybody, e);
                    continue;
                }
            },
            None => {
                eprintln!("No value found for key {:?}", keybody);
                continue;
            }
        };
        let taxid: i64 = rmp_serde::from_slice(&keybody).expect("Deserialization error for key");
        graph.insert(taxid, node);
    }
    graph
}
