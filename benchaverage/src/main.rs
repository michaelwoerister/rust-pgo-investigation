
use std::io;
use std::fs;
use regex::*;
use std::io::{BufRead};

fn main() {
    // misc::anchored_literal_long_match        12,320                                                          13,100                                                            780    6.33%   x 0.94
    let regex = Regex::new(r".*([[:digit:]]+\.[[:digit:]]+)[[:space:]]*$").unwrap();

    let mut average_speedups = vec![];

    // Iterate over files matching the prefix
    for dir_entry in fs::read_dir(".").unwrap() {
        let dir_entry = dir_entry.unwrap();

        if !dir_entry.file_name().to_string_lossy().starts_with("comparison-") {
            continue;
        }

        let file = fs::File::open(dir_entry.path()).unwrap();

        let mut speedups = Vec::new();

        for line in io::BufReader::new(file).lines() {
            let line = line.unwrap();
            if let Some(captures) = regex.captures(&line) {
                let speedup: f64 = str::parse(&captures[1]).unwrap();
                speedups.push(speedup);
            }
        }

        let file_name = dir_entry.file_name().to_string_lossy().into_owned();
        let average = speedups.iter().cloned().sum::<f64>() / (speedups.len() as f64);

        average_speedups.push((file_name, average));
    }

    average_speedups.sort_by_key(|&(_, speedup)| (speedup * 1000_000.0) as i64);

    for (file_name, speedup) in average_speedups {
        println!(
            "{:100}{:>5.3}",
            file_name,
            speedup,
        );
    }
}
