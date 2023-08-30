//go:build linux
// +build linux

package main

import (
	"log"

	"github.com/cilium/ebpf/rlimit"
	"golang.org/x/sys/unix"
)

func main() {
	if err := unix.Setrlimit(unix.RLIMIT_NOFILE, &unix.Rlimit{
		Cur: 8192,
		Max: 8192,
	}); err != nil {
		log.Fatalf("failed to set temporary rlimit: %s", err)
	}
	if err := rlimit.RemoveMemlock(); err != nil {
		log.Fatalf("Failed to set temporary rlimit: %s", err)
	}
	bpf := NewBPF()
	if err := bpf.Load(); err != nil {
		log.Fatal(err)
	}
	defer bpf.Close()
	_, err := bpf.Attach()
	if err != nil {
		log.Fatalf("failed to attach kprobes:%s", err)
	}

}
