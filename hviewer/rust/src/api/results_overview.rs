pub struct Domain{
    pub name: String,
    pub start: i32,
    pub end: i32,
    pub evalue: f64,
  }
  
  pub struct Hit{
    pub name: String,  // Name of the sequence that the hit was to
    pub sequence: String,  // Sequence  that was hit
    pub domains: Vec<Domain>,
    pub queries: Vec<Domain>,  // Queries that were hit
  }
  
  pub struct SigCategory{
    pub num_hits: i32,
    pub signature: String,
    pub example: Hit,
  }
  
  pub struct ResultsOverview{
    pub num_hits: i32,
    pub num_categories: i32,
    pub categories: Vec<SigCategory>,
  }

#[frb(unignore)]
pub struct HitList{
    pub numHits: i32,
    pub signature: String,
    pub hits: Vec<Hit>,
}


pub fn demo()->ResultsOverview{
    let mut categories = Vec::new();
    let ex1 = Hit{
        name: "Example 1".to_string(),
        sequence: "ACGTACGTACGTACGTACGTACGT".to_string(),
        domains: vec![Domain{name: "Domain1".to_string(), start: 1, end: 5, evalue: 0.1}, 
                     Domain{name: "Domain2".to_string(), start: 6, end: 10, evalue: 0.01},
                     Domain{name: "Domain3".to_string(), start: 11, end: 15, evalue: 0.001}],
        queries: vec![Domain{name: "query1".to_string(), start: 1, end: 5, evalue: 0.1}, 
                     Domain{name: "query2".to_string(), start: 6, end: 10, evalue: 0.01},
                     Domain{name: "query3".to_string(), start: 11, end: 15, evalue: 0.001}], 
    };
    let cat1 = SigCategory{
        num_hits: 5,
        signature: "Domain1-Domain2-Domain3".to_string(),
        example: ex1,
    };
    categories.push(cat1);
    let results = ResultsOverview{
        num_hits: 5,
        num_categories: 1,
        categories: categories,
    };
    results

}