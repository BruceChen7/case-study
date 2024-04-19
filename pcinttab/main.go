package main

import (
	"debug/elf"
	"debug/gosym"
	"fmt"
	"os"
	"runtime"

	"github.com/pkg/errors"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func goSymTable() (*gosym.Table, error) {
	exe, err := elf.Open(os.Args[0])
	if err != nil {
		return nil, errors.Wrap(err, "failed to open executable")
	}
	addr := exe.Section(".text").Addr
	lineTabData, err := exe.Section(".gopclntab").Data()
	if err != nil {
		return nil, errors.Wrap(err, "failed to read .gopclntab")
	}
	lineTable := gosym.NewLineTable(lineTabData, addr)
	symTableData, err := exe.Section(".gosymtab").Data()
	if err != nil {
		return nil, errors.Wrap(err, "failed to read .gosymtab")
	}
	return gosym.NewTable(symTableData, lineTable)
}

func run() error {
	symTable, err := goSymTable()
	if err != nil {
		return errors.Wrap(err, "failed to acquire sym table")
	}
	for _, pc := range callers() {
		file, line, fn := symTable.PCToLine(uint64(pc))
		fmt.Printf("%x: %s() %s:%d\n", pc, fn.Name, file, line)
	}
	return nil
}

func callers() []uintptr {
	pcs := make([]uintptr, 32)
	n := runtime.Callers(2, pcs)
	pcs = pcs[0:n]
	return pcs
}
