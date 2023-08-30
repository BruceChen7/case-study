// Code generated by bpf2go; DO NOT EDIT.
//go:build 386 || amd64

package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"io"

	"github.com/cilium/ebpf"
)

// LoadVFSReadLatency returns the embedded CollectionSpec for VFSReadLatency.
func LoadVFSReadLatency() (*ebpf.CollectionSpec, error) {
	reader := bytes.NewReader(_VFSReadLatencyBytes)
	spec, err := ebpf.LoadCollectionSpecFromReader(reader)
	if err != nil {
		return nil, fmt.Errorf("can't load VFSReadLatency: %w", err)
	}

	return spec, err
}

// LoadVFSReadLatencyObjects loads VFSReadLatency and converts it into a struct.
//
// The following types are suitable as obj argument:
//
//	*VFSReadLatencyObjects
//	*VFSReadLatencyPrograms
//	*VFSReadLatencyMaps
//
// See ebpf.CollectionSpec.LoadAndAssign documentation for details.
func LoadVFSReadLatencyObjects(obj interface{}, opts *ebpf.CollectionOptions) error {
	spec, err := LoadVFSReadLatency()
	if err != nil {
		return err
	}

	return spec.LoadAndAssign(obj, opts)
}

// VFSReadLatencySpecs contains maps and programs before they are loaded into the kernel.
//
// It can be passed ebpf.CollectionSpec.Assign.
type VFSReadLatencySpecs struct {
	VFSReadLatencyProgramSpecs
	VFSReadLatencyMapSpecs
}

// VFSReadLatencySpecs contains programs before they are loaded into the kernel.
//
// It can be passed ebpf.CollectionSpec.Assign.
type VFSReadLatencyProgramSpecs struct {
	DoEntry  *ebpf.ProgramSpec `ebpf:"do_entry"`
	DoReturn *ebpf.ProgramSpec `ebpf:"do_return"`
}

// VFSReadLatencyMapSpecs contains maps before they are loaded into the kernel.
//
// It can be passed ebpf.CollectionSpec.Assign.
type VFSReadLatencyMapSpecs struct {
	ReadEvents   *ebpf.MapSpec `ebpf:"read_events"`
	ResultEvents *ebpf.MapSpec `ebpf:"result_events"`
}

// VFSReadLatencyObjects contains all objects after they have been loaded into the kernel.
//
// It can be passed to LoadVFSReadLatencyObjects or ebpf.CollectionSpec.LoadAndAssign.
type VFSReadLatencyObjects struct {
	VFSReadLatencyPrograms
	VFSReadLatencyMaps
}

func (o *VFSReadLatencyObjects) Close() error {
	return _VFSReadLatencyClose(
		&o.VFSReadLatencyPrograms,
		&o.VFSReadLatencyMaps,
	)
}

// VFSReadLatencyMaps contains all maps after they have been loaded into the kernel.
//
// It can be passed to LoadVFSReadLatencyObjects or ebpf.CollectionSpec.LoadAndAssign.
type VFSReadLatencyMaps struct {
	ReadEvents   *ebpf.Map `ebpf:"read_events"`
	ResultEvents *ebpf.Map `ebpf:"result_events"`
}

func (m *VFSReadLatencyMaps) Close() error {
	return _VFSReadLatencyClose(
		m.ReadEvents,
		m.ResultEvents,
	)
}

// VFSReadLatencyPrograms contains all programs after they have been loaded into the kernel.
//
// It can be passed to LoadVFSReadLatencyObjects or ebpf.CollectionSpec.LoadAndAssign.
type VFSReadLatencyPrograms struct {
	DoEntry  *ebpf.Program `ebpf:"do_entry"`
	DoReturn *ebpf.Program `ebpf:"do_return"`
}

func (p *VFSReadLatencyPrograms) Close() error {
	return _VFSReadLatencyClose(
		p.DoEntry,
		p.DoReturn,
	)
}

func _VFSReadLatencyClose(closers ...io.Closer) error {
	for _, closer := range closers {
		if err := closer.Close(); err != nil {
			return err
		}
	}
	return nil
}

// Do not access this directly.
//
//go:embed vfsreadlatency_bpfel_x86.o
var _VFSReadLatencyBytes []byte
