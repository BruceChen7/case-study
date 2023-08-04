package main

import (
	"debug/dwarf"
	"debug/elf"
	"flag"
	"fmt"
	"os"

	"github.com/pkg/errors"
	"golang.org/x/arch/x86/x86asm"
)

var (
	binaryPath = flag.String("binary", "", "path to binary")
	symbolName = flag.String("symbol", "", "name of symbol to find")
)

func main() {
	// using flags to parse command line arguments to get file path
	flag.Parse()
	if *binaryPath == "" {
		fmt.Println("binary path is required")
		os.Exit(1)
	}
	if *symbolName == "" {
		fmt.Println("symbol name is required")
		os.Exit(1)
	}

	filePath := *binaryPath

	f, err := os.Open(filePath)
	if err != nil {
		fmt.Println("Error opening file:", err)
		return
	}
	defer f.Close()

	ef, err := elf.NewFile(f)
	if err != nil {
		fmt.Println("Error reading ELF file:", err)
		return
	}
	defer ef.Close()
        fetchReturnAddr(f, ef, *symbolName)
}

func fetchReturnAddr(f *os.File, ef *elf.File, funcName string) ([]uint64, error) {
	dw, err := ef.DWARF()
	if err != nil {
		fmt.Println("Error reading DWARF data:", err)
		return nil, err
	}
	lowpc, highpc, err := findFuncRangeAddrFromDwarf(dw, funcName)
	if err != nil {
                fmt.Println("Error finding function range:", err)
                // 尝试从symboltab
                return nil, err
	}
	section := ef.Section(".text")
        offset := section.Offset
        size := section.Size
        textBytes := make([]byte, size)
        _, err = f.ReadAt(textBytes, int64(offset))
        if err != nil {
                return nil, err
        }


	if highpc > uint64(len(textBytes))+section.Addr || lowpc < section.Addr {
		err = errors.Wrap(errors.New("PC range too large"), funcName)
		return nil, err
	}
        // lowpc is absolute address, 
	// instructions := textBytes[lowpc-section.Addr : highpc-section.Addr],
        instructions := textBytes[lowpc-section.Addr : highpc-section.Addr]
        offset = lowpc - section.Addr + section.Offset
        insts := resolveInstructions(instructions)
        offsets := make([]uint64, 0, len(insts))
        // return textBytes[lowpc-section.Addr : highpc-section.Addr], nil
        for _, inst := range insts {
                if inst.Op == x86asm.RET {
                        offsets = append(offsets, offset)
                }
                offset += uint64(inst.Len)
        }
        return offsets, nil
}

func resolveInstructions(bytes []byte) ([]x86asm.Inst) {
        if len(bytes) == 0 {
                return nil
        }
        insts := make([]x86asm.Inst, 0, len(bytes))
        for {
                inst, err := x86asm.Decode(bytes, 64)
                if err != nil {
                        inst = x86asm.Inst{Len: 1}
                }
                        insts = append(insts, inst)
                bytes = bytes[inst.Len:]
                if len(bytes) == 0 {
                        break
                }
        }
        return insts
}

func findFuncRangeAddrFromDwarf(dw *dwarf.Data, funcName string) (uint64, uint64, error) {
	// Search the ".debug_info" section for the function.
	r := dw.Reader()

	for {
		entry, err := r.Next()
		if err != nil {
			return 0, 0, err
		}

		// When we reach an entry that is nil, we have read all entries, so exit.
		if entry == nil {
			break
		}

		// If this entry represents a function/subprogram and its name matches our target,
		// we have found the target function.
		if entry.Tag == dwarf.TagSubprogram {
			if entry.Val(dwarf.AttrName) == funcName {
				startAddr := entry.Val(dwarf.AttrLowpc).(uint64)
				endAddr := entry.Val(dwarf.AttrHighpc).(uint64)
				return startAddr, endAddr, nil
			}
		}
	}
	return 0, 0, errors.New(fmt.Sprintf("could not find function %s", funcName))
}

