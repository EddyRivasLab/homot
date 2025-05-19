use flutter_rust_bridge::frb;
use rand::prelude::*;

pub struct Graph {
    pub num_levels: usize,
    pub leaves_per_level: Vec<u64>,
    pub nodes: Vec<Node>,
}

pub struct Node{
    pub name: String,
    pub children: Vec<usize>,
    pub parent: Option<usize>,
    pub num_leaves: u64,
    pub num_hits: u64
}

#[frb(serialize)]
#[frb(sync)]
pub fn fetch_graph(num_levels: usize) -> Graph {
    let mut rng = rand::rng();
    let mut graph = Graph{nodes: Vec::new(), num_levels: num_levels, leaves_per_level: vec![0; num_levels]};
    let node = Node{name: String::from("root"),
                        children: Vec::new(),
                        parent: None,
                        num_leaves: 0,
                        num_hits: 0};
    graph.nodes.push(node);   
    add_children_to_node(&mut graph, &mut rng, num_levels-1, 0, 6);
    count_leaves(&mut graph, 0_usize, 0);
    graph
}

fn count_leaves(graph: &mut Graph, node_id: usize, level: usize) -> u64 {
    let mut count = 0;
    if graph.nodes[node_id].children.len() == 0{
        graph.nodes[node_id].num_leaves = 1;
        graph.leaves_per_level[level] +=1;
        return 1;
    }
    for child in graph.nodes[node_id].children.clone(){
        count += count_leaves(graph, child, level+1);
    }
    graph.nodes[node_id].num_leaves = count;
    graph.leaves_per_level[level] += count;
    count
}

fn add_children_to_node(graph: &mut Graph,  rng:&mut impl Rng, remaining_levels: usize, which_node: usize, max_children: u64) {
  if which_node >= graph.nodes.len() {
    panic!("Node {} does not exist", which_node);  
  }
  if max_children < 2{
    panic!("Max children must be at least 2");
  }
  if remaining_levels == 0 {
    return;
    }   

    //let mut root = graph.nodes[which_node];
    let num_children = rng.random_range(2..max_children);
    for _ in 0..num_children {
        let mut child = Node{name: graph.nodes.len().to_string(),
        children: Vec::new(),
        parent: None,
        num_leaves: 0,
        num_hits: 0};

        child.parent = Some(which_node);        
        graph.nodes.push(child);
        let child_id = graph.nodes.len() - 1;
        graph.nodes[which_node].children.push(child_id);
        add_children_to_node(graph, rng, remaining_levels - 1, child_id, max_children);
    }
} 