#!/bin/bash

root_dir=$(pwd)

# build the benchmerge tool, which merges a number of benchmark outputs into a
# single one
cd $root_dir/benchmerge
cargo build
benchmerge=$root_dir/benchmerge/target/debug/benchmerge

# install the cargo-benchcmp tool
cargo install -f cargo-benchcmp

# run non-PGO benchmarks
rm -rf $root_dir/non-pgo-timings
mkdir -p $root_dir/non-pgo-timings

cd $root_dir/regex
rustup override set nightly
cargo clean

cd $root_dir/regex/bench

for i in {1..20}
do
    echo "Non-PGO benchmark pass $i of 20"
    ./run rust > $root_dir/non-pgo-timings/timings-`date +%s`.txt
done

# merge the benchmark results from the non-PGO benchmarks
cd $root_dir/non-pgo-timings
$benchmerge

# run PGO benchmarks
#
# (1) run benchmarks with instrumentation enabled
cd $root_dir/regex
cargo clean

rm -rf $root_dir/regex-samples
mkdir -p $root_dir/regex-samples

cd $root_dir/regex/bench

for i in {1..20}
do
    echo "PGO Instrumentation pass $i of 20"
    RUSTFLAGS="-Cprofile-generate=$root_dir/regex-samples" ./run rust > /dev/null
done

# (2) merge the profiling data
llvm-profdata merge -o $root_dir/regex-samples/merged.profdata $root_dir/regex-samples

# (3) run benchmarks with PGO applied
rm -rf $root_dir/pgo-timings
mkdir -p $root_dir/pgo-timings

for i in {1..20}
do
    echo "PGO benchmark pass $i of 20"
    RUSTFLAGS="-Cprofile-use=$root_dir/regex-samples/merged.profdata" ./run rust > $root_dir/pgo-timings/timings-`date +%s`.txt
done

# merge the benchmark results from the PGO benchmarks
cd $root_dir/pgo-timings
$benchmerge

# run PGO benchmarks with pre-inlining pass disabled
#
# (1) run benchmarks with instrumentation enabled
cd $root_dir/regex
cargo clean

rm -rf $root_dir/regex-samples-no-preinlining
mkdir -p $root_dir/regex-samples-no-preinlining

cd $root_dir/regex/bench

for i in {1..20}
do
    echo "PGO Instrumentation pass $i of 20 (no pre-inlining)"
    RUSTFLAGS="-Cprofile-generate=$root_dir/regex-samples-no-preinline -Zdisable-instrumentation-preinliner" ./run rust > /dev/null
done

# (2) merge the profiling data
llvm-profdata merge -o $root_dir/regex-samples-no-preinline/merged.profdata $root_dir/regex-samples-no-preinline

# (3) run benchmarks with PGO applied
rm -rf $root_dir/pgo-timings-no-preinline
mkdir -p $root_dir/pgo-timings-no-preinline

for i in {1..20}
do
    echo "PGO benchmark pass $i of 20 (no pre-inlining)"
    RUSTFLAGS="-Cprofile-use=$root_dir/regex-samples-no-preinline/merged.profdata -Zdisable-instrumentation-preinliner" ./run rust > $root_dir/pgo-timings-no-preinline/timings-`date +%s`.txt
done

# merge the benchmark results from the PGO benchmarks
cd $root_dir/pgo-timings-no-preinline
$benchmerge

echo "COMPARISON - Regular PGO vs PGO without pre-inlining pass"
cargo benchcmp $root_dir/pgo-timings/merged-timings.txt $root_dir/pgo-timings-no-preinline/merged-timings.txt | tee $root_dir/comparison-pgo-pre-inlining-vs-no-pre-inlining.txt

echo "COMPARISON - Regular Non-PGO vs Regular PGO (=with pre-inlining pass)"
cargo benchcmp $root_dir/non-pgo-timings/merged-timings.txt $root_dir/pgo-timings/merged-timings.txt | tee $root_dir/comparison-no-pgo-vs-pgo.txt

echo "COMPARISON - Regular Non-PGO vs PGO *without* pre-inlining pass"
cargo benchcmp $root_dir/non-pgo-timings/merged-timings.txt $root_dir/pgo-timings-no-preinline/merged-timings.txt | tee $root_dir/comparison-no-pgo-vs-pgo-no-pre-inlining.txt

