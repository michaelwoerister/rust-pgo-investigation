#!/bin/bash

cd /xoxo/rust-pgo-investigation/regex-non-pgo
rustup override set nightly
cargo clean
rm -f /xoxo/rust-pgo-investigation/non-pgo-timings/timings*

for i in {1..25}
do
    (cd bench && ./run rust > /xoxo/rust-pgo-investigation/non-pgo-timings/timings-`date +%s`.txt)
done


cd /xoxo/rust-pgo-investigation/regex
rustup override set nightly
cargo clean
rm -f /xoxo/rust-pgo-investigation/regex-samples/*

for i in {1..25}
do
    (cd bench && RUSTFLAGS=-Cprofile-generate=/xoxo/rust-pgo-investigation/regex-samples ./run rust > /dev/null)
done

llvm-profdata merge -o /xoxo/rust-pgo-investigation/regex-samples/merged.profdata /xoxo/rust-pgo-investigation/regex-samples

rm -f /xoxo/rust-pgo-investigation/pgo-timings/timings*
for i in {1..25}
do
    (cd bench && RUSTFLAGS=-Cprofile-use=/xoxo/rust-pgo-investigation/regex-samples/merged.profdata ./run rust > /xoxo/rust-pgo-investigation/pgo-timings/timings-`date +%s`.txt)
done
