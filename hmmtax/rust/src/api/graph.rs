use flutter_rust_bridge::frb;
use rand::prelude::*;

pub struct Graph {
    pub nodes: Vec<Node>,
}

pub struct Node{
    pub name: String,
    pub children: Vec<usize>,
    pub parent: Option<usize>,
    pub num_descendants: u64,
    pub num_hits: u64
}

#[frb(serialize)]
#[frb(sync)]
pub fn fetch_graph(num_levels: u64) -> Graph {
    let mut rng = rand::rng();
    let mut graph = Graph{nodes: Vec::new()};
    let node = Node{name: String::from("root"),
                        children: Vec::new(),
                        parent: None,
                        num_descendants: 0,
                        num_hits: 0};
    graph.nodes.push(node);   
    add_children_to_node(&mut graph, &mut rng, num_levels-1, 0, 6);
    count_descendants(&mut graph, 0_usize);
    graph
}

fn count_descendants(graph: &mut Graph, node_id: usize) -> u64 {
    let mut count = 0;
    for child in graph.nodes[node_id].children.clone(){
        count += 1 + count_descendants(graph, child);
    }
    graph.nodes[node_id].num_descendants = count;
    count
}

fn add_children_to_node(graph: &mut Graph,  rng:&mut impl Rng, remaining_levels: u64, which_node: usize, max_children: u64) {
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
        num_descendants: 0,
        num_hits: 0};

        child.parent = Some(which_node);        
        graph.nodes.push(child);
        let child_id = graph.nodes.len() - 1;
        graph.nodes[which_node].children.push(child_id);
        add_children_to_node(graph, rng, remaining_levels - 1, child_id, max_children);
    }
} 