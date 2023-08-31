//go:build linux
// +build linux

package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

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
	log.Println("attach kprobes success")
	defer bpf.Close()
	kprobes, err := bpf.Attach()
	if err != nil {
		log.Fatalf("failed to attach kprobes:%s", err)
	}
	defer func() {
		for _, k := range kprobes {
			k.Close()
		}
	}()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	events := bpf.GetEvents()
	for {
		event := Event{}
		for {
			if err := events.LookupAndDelete(nil, &event); err == nil {
				break
			}
			select {
			case <-ctx.Done():
				return
			case <-time.After(time.Microsecond):
				continue
			}

		}
		fmt.Printf("comman %s, elapsed %d\n", event.Comm, event.Elasped)
	}
}
