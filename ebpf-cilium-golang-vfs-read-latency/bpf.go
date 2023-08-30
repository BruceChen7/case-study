package main

import (
	"fmt"
	"io"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
)

var (
	ErrorLoadSpec error = fmt.Errorf("can't load VFSReadLatency")
)

type BPF struct {
	objs    *VFSReadLatencyObjects
	closers []io.Closer
}

func NewBPF() *BPF {
	return &BPF{}
}

func (b *BPF) Load() error {
	spec, err := LoadVFSReadLatency()
	if err != nil {
		return err
	}
	b.objs = &VFSReadLatencyObjects{}
	defer func() {
		if err != nil {
			return
		}
		b.closers = append(b.closers, b.objs.ReadEvents)
		// close event stack
		b.closers = append(b.closers, b.objs.ResultEvents)
	}()
	err = spec.LoadAndAssign(b.objs, &ebpf.CollectionOptions{
		Programs: ebpf.ProgramOptions{LogSize: ebpf.DefaultVerifierLogSize * 4},
	})
	if err != nil {
		return err
	}
	return nil
}

func (b *BPF) Attach() ([]link.Link, error) {
	var kprobes []link.Link
	kp, err := link.Kprobe("vfs_read", b.objs.DoEntry, nil)
	if err != nil {
		return nil, err
	}
	kprobes = append(kprobes, kp)
	kp, err = link.Kretprobe("vfs_read", b.objs.DoReturn, nil)
	if err != nil {
		return nil, err
	}
	kprobes = append(kprobes, kp)
	return kprobes, nil
}

func (b *BPF) Close() error {
	for _, c := range b.closers {
		if err := c.Close(); err != nil {
			return err
		}
	}
	return nil
}
