package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	id, err := loadOrCreateIdentity()
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
	switch os.Args[1] {
	case "pair":
		if err := pairCommand(id, nameOf(id)); err != nil {
			fmt.Fprintln(os.Stderr, "error:", err)
			os.Exit(1)
		}
	case "watch":
		if err := watchCommand(id); err != nil {
			fmt.Fprintln(os.Stderr, "error:", err)
			os.Exit(1)
		}
	case "version", "-v", "--version":
		fmt.Println("clipshare 0.1.0")
	default:
		usage()
		os.Exit(1)
	}
}

func usage() {
	fmt.Println("usage: clipshare <pair|watch|version>")
	fmt.Println("  pair   register a device (show or enter a 6-character code)")
	fmt.Println("  watch  sync the clipboard with paired devices on this network")
}
