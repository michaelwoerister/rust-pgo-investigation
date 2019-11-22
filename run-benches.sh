#!/bin/bash

root_dir=$(pwd)

# build the benchmerge tool, which merges a number of benchmark outputs into a
# single one
cd $root_dir/benchmerge
cargo build
benchmerge=$root_dir/benchmerge/target/debug/benchmerge

install the cargo-benchcmp tool
cargo install -f cargo-benchcmp

function run_benchmark() {
     local timings_dir=$1
     local rust_flags=$2

     # run non-PGO benchmarks with 1 cgu
     rm -rf $root_dir/$timings_dir
     mkdir -p $root_dir/$timings_dir

     cd $root_dir/regex
     rustup override set nightly
     cargo clean

     cd $root_dir/regex/bench

     echo "RUSTFLAGS=$rust_flags"

     for i in {1..15}
     do
         echo "$timings_dir: Pass $i of 15"
         RUSTFLAGS="$rust_flags" ./run rust > $root_dir/$timings_dir/timings-`date +%s`.txt
     done

     # merge the benchmark results from the non-PGO benchmarks
     cd $root_dir/$timings_dir
     $benchmerge
}

function run_instrumented_benchmark() {
     local caption=$1
     local rust_flags=$2

     cd $root_dir/regex
     rustup override set nightly
     cargo clean

     cd $root_dir/regex/bench

     echo "RUSTFLAGS=$rust_flags"

     for i in {1..4}
     do
         echo "$caption: Pass $i of 4"
         RUSTFLAGS="$rust_flags" ./run rust
     done
}

function run_pgo_benchmark() {

     local caption=$1
     local profile_directory=$2
     local cgu_count=$3

     rm -rf $root_dir/$profile_directory
     mkdir -p $root_dir/$profile_directory

     run_instrumented_benchmark "$1-generate" "-Ccodegen-units=$cgu_count \
                                               -Clinker=clang-8 \
                                               -Cllvm-args=-import-instr-limit=10 \
                                               -Clink-args=-fuse-ld=lld \
                                               -Cprofile-generate=$root_dir/$profile_directory"
     llvm-profdata merge -o $root_dir/$profile_directory/merged.profdata $root_dir/$profile_directory
     run_benchmark "$1-use" "-Ccodegen-units=$cgu_count \
                             -Clinker=clang-8 \
                             -Cllvm-args=-import-instr-limit=10 \
                             -Clink-args=-fuse-ld=lld \
                             -Cprofile-use=$root_dir/$profile_directory/merged.profdata"
}


run_benchmark "final-non-pgo-1-cgu-instr-limit" "-Ccodegen-units=1 -Clinker=clang-8 -Clink-args=-fuse-ld=lld -Cllvm-args=-import-instr-limit=10"
run_benchmark "final-non-pgo-N-cgus-instr-limit" "-Ccodegen-units=1000 -Clinker=clang-8 -Clink-args=-fuse-ld=lld -Cllvm-args=-import-instr-limit=10"

run_pgo_benchmark "final-pgo-1-cgu-instr-limit" "final-pgo-data-1-cgu-instr-limit" 1
run_pgo_benchmark "final-pgo-N-cgus-instr-limit" "final-pgo-data-N-cgus-instr-limit" 1000
