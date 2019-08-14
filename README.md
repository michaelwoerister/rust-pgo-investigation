

`./run-benches.sh` runs the regex bench 25x times.
`benchmerge` merges (=averages) the benchmark results.
`cargo benchcmp` can be used to compared merged results.

`./regex` contains a recent copy of the regex library
`./regex-non-pgo` is the same as regex, compiled without PGO
