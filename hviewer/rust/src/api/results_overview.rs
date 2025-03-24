use flutter_rust_bridge::frb;

#[derive(Clone)]
pub struct Domain{
    pub name: String,
    pub start: i32,
    pub end: i32,
    pub evalue: f64,
  }

  #[derive(Clone)]
  pub struct Hit{
    pub name: String,  // Name of the sequence that the hit was to
    pub sequence: String,  // Sequence  that was hit
    pub domains: Vec<Domain>,
    pub queries: Vec<Domain>,  // Queries that were hit
  }

  #[derive(Clone)]
  pub struct SigCategory{
    pub num_hits: i32,
    pub signature: String,
    pub example: Hit, 
  }

  #[derive(Clone)]
#[frb(unignore)]  
pub struct ResultsOverview{
    pub num_hits: i32,
    pub num_categories: i32,
    pub categories: Vec<SigCategory>,
  }

#[derive(Clone)]
#[frb(unignore)]
pub struct HitList{
    pub num_hits: i32,
    pub signature: String,
    pub hits: Vec<Hit>,
}

#[derive(Clone)]
#[frb(unignore)]
pub struct SearchResults{
  pub succeeded: bool,
  pub err_msg: String,
  pub overview: ResultsOverview,
  pub hit_lists: Vec<HitList>,
}

#[frb(serialize)]
#[frb(sync)]
pub fn load_data(annotations: String, domtblout_files: Vec<String>) -> SearchResults{
  let dom1 = Domain{
    name: "Domain1".to_string(),
    start: 15,
    end: 40,
    evalue: 0.01,
  };
  let dom2 = Domain{
    name: "Domain2".to_string(),
    start: 55,
    end: 90,
    evalue: 0.01,
  };
  let query1 = Domain{
    name: "Query1".to_string(),
    start: 8,
    end: 50,
    evalue: 0.01,
  };
  let query2 = Domain{
    name: "Query2".to_string(),
    start: 70,
    end: 100,
    evalue: 0.01,
  };
  let hit = Hit{
    name: "sp|Q6GZX4|001R_FRG3G".to_string(),
    sequence: "MAFSAEDVLKEYDRRRRMEALLLSLYYPNDRKLLDYKEWSPPRVQVECPKAPVEWNNPPSEKGLIVGHFSGIKYKGEKAQASEVDVNKMCCWVSKFKDAMRRYQGIQTCKIPGKVLSDLDAKIKAYNLTVEGVEGFVRYSRVTKQHVAAFLKELRHSKQYENVNLIHYILTDKRVDIQHLEKDLVKDFKALVESAHRMRQGHMINVKYILYQLLKKHGHGPDGPDILTVKTGSKGVLYDDSFRKIYTDLGWKFTP".to_string(),
    domains: vec![dom1.clone(), dom2.clone()],
    queries: vec![query1.clone(), query2.clone()],
  };

  let category = SigCategory{
    num_hits: 12,
    signature: "Sample Domain Architecture".to_string(),
    example: hit.clone(),
  };
  let hit_list = HitList{
    num_hits: 12,
    signature: "Sample Domain Architecture".to_string(),
    hits: vec![hit.clone(), hit.clone(),hit.clone(),hit.clone(), hit.clone(),hit.clone(),hit.clone(), hit.clone(),hit.clone(),hit.clone(), hit.clone(),hit.clone(),], 
  };
  let overview = ResultsOverview{
    num_hits: 60,
    num_categories: 5,
    categories: vec![category.clone(), category.clone(), category.clone(), category.clone(), category.clone()],
  };

  let mut results = SearchResults{
    succeeded: true,
    err_msg: "That Didn't Work".to_string(),
    hit_lists: Vec::new(),
    overview: overview,
  };
  results.hit_lists.push(hit_list.clone());
  results.hit_lists.push(hit_list.clone());
  results.hit_lists.push(hit_list.clone());
  results.hit_lists.push(hit_list.clone());
  results.hit_lists.push(hit_list.clone());
  results
}
