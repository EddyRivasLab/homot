pub struct Domain{
    pub name: String,
    pub start: i32,
    pub end: i32,
}

pub struct Sequence{
    pub name: String,
    pub sequence: String,
    pub domains: Vec<Domain>,
}

pub struct SigCategory{
    pub num_hits: i32,
    pub signature: String,
    pub example: Sequence,
}

pub struct ResultsOverview{
    pub num_hits: i32,
    pub num_categories: i32,
    pub categories: Vec<SigCategory>,
}

pub fn demo()->ResultsOverview{
    let mut categories = Vec::new();
    let ex1 = Sequence{
        name: "Example 1".to_string(),
        sequence: "ACGTACGTACGTACGTACGTACGT".to_string(),
        domain: vec![Domain{name: "Domain1".to_string(), start: 1, end: 5}, 
                     Domain{name: "Domain2".to_string(), start: 6, end: 10},
                     Domain{name: "Domain3".to_string(), start: 11, end: 15}],
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