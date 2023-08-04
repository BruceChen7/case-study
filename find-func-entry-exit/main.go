package main

import (
	"debug/dwarf"
	"debug/elf"
	"fmt"
	"os"
)

func main() {
	filePath := "./path/to/your/binary"

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

	dw, err := ef.DWARF()
	if err != nil {
		fmt.Println("Error reading DWARF data:", err)
		return
	}

	funcName := "yourFunc" // replace with the name of your function
	returnAddr, err := findFuncReturnAddr(dw, funcName)
	if err != nil {
		fmt.Println("Error finding function:", err)
		return
	}

	fmt.Printf("The return address of function %s is %x\n", funcName, returnAddr)
}

func findFuncReturnAddr(dw *dwarf.Data, funcName string) (uint64, error) {
	// Search the ".debug_info" section for the function.
	r := dw.Reader()

	for {
		entry, err := r.Next()
		if err != nil {
			return 0, err
		}

		// When we reach an entry that is nil, we have read all entries, so exit.
		if entry == nil {
			break
		}

		// If this entry represents a function/subprogram and its name matches our target,
		// we have found the target function.
		if entry.Tag == dwarf.TagSubprogram {
			if entry.Val(dwarf.AttrName) == funcName {
				// The entry's field "AttrLowpc" is the start address in virtual memory
				// at which the function's machine instructions begin.
				// The function's return address is thus one less than this.
				return entry.Val(dwarf.AttrLowpc).(uint64) - uint64(1), nil
			}
		}
	}
	return 0, fmt.Errorf("function %s not found", funcName)
}

