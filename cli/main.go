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
	switch os.Args[1] {
	case "pair":
		fmt.Println("pair: not implemented yet")
	case "watch":
		fmt.Println("watch: not implemented yet")
	case "version", "-v", "--version":
		fmt.Println("clipshare 0.1.0-dev")
	default:
		usage()
		os.Exit(1)
	}
}

func usage() {
	fmt.Println("usage: clipshare <pair|watch|version>")
}
