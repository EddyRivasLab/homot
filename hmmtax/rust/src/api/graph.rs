use flutter_rust_bridge::frb;
use serde::{Serialize, Deserialize};
use fjall::{Config, PartitionCreateOptions,UserValue, Slice};
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Clone)]
pub struct Node{
    pub taxid: i64,
    pub parent: i64,
    pub children: Vec<i64>,
    pub rank: String,
    pub ranknum: u32,
    pub name: String,
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
