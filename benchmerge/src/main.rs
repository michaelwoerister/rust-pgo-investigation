
use std::collections::BTreeMap;
use std::io;
use std::fs;
use regex::*;
use std::io::{Write, BufRead};

fn main() {
    // Allocate dictionary of benchmark -> ns
    let mut timings = BTreeMap::new();

    // test regexdna::variant8                      ... bench:   3,277,263 ns/iter (+/- 71,273) = 1551 MB/s
    let regex = Regex::new(r"test (\S+)\s*... bench:\s+([0-9,]+)\s+").unwrap();

    let mut num_files = 0;

    let mut header = String::new();
    let mut footer = String::new();

    // Iterate over files matching the prefix
    for dir_entry in fs::read_dir(".").unwrap() {
        let dir_entry = dir_entry.unwrap();

        if !dir_entry.file_name().to_string_lossy().starts_with("timings-") {
            continue;
        }

        println!("Processing file {}", dir_entry.path().display());

        let mut header_complete = false;

        let file = fs::File::open(dir_entry.path()).unwrap();
        for line in io::BufReader::new(file).lines() {
            let line = line.unwrap();
            if let Some(captures) = regex.captures(&line) {
                println!("Found benchmark line: {}", &captures[0]);

                let benchmark_name = &captures[1];
                println!("extracted name: {}", benchmark_name);
                let ns = captures[2].replace(",", "");

                assert!(ns.chars().all(|c| c.is_ascii_digit()));

                let ns: u64 = ns.parse().unwrap();

                println!("extracted & parsed ns: {}", ns);

                if !timings.contains_key(benchmark_name) {
                    timings.insert(benchmark_name.to_owned(), 0);
                }

                *timings.get_mut(benchmark_name).unwrap() += ns;

                header_complete = true;
            } else if num_files == 0 {
                use std::fmt::Write;

                if !header_complete {
                    writeln!(header, "{}", line).unwrap();
                } else {
                    writeln!(footer, "{}", line).unwrap();
                }
            }
        }

        num_files += 1;
    }

    for (_, timing) in &mut timings {
        *timing = (*timing * 1000) / num_files;
    }

    // open file
    let mut file = fs::File::create("merged-timings.txt").unwrap();

    write!(file, "{}", header).unwrap();

    for (benchmark_name, ns) in timings {
        writeln!(file, "test {:<40} ... bench: {:>40} ns/iter (+/- 0)", benchmark_name, fmt_thousands_sep(ns, ',')).unwrap();
    }

    write!(file, "{}", footer).unwrap();
}


// Format a number with thousands separators
fn fmt_thousands_sep(mut n: u64, sep: char) -> String {
    use std::fmt::Write;
    let mut output = String::new();
    let mut trailing = false;
    for &pow in &[9, 6, 3, 0] {
        let base = 10_u64.pow(pow);
        if pow == 0 || trailing || n / base != 0 {
            if !trailing {
                output.write_fmt(format_args!("{}", n / base)).unwrap();
            } else {
                output.write_fmt(format_args!("{:03}", n / base)).unwrap();
            }
            if pow != 0 {
                output.push(sep);
            }
            trailing = true;
        }
        n %= base;
    }

    output
}
