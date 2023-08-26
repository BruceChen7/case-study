package main

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -cc clang -no-strip -target native  vf_read_latency ./vfs_read_latency.c -- -I./headers
