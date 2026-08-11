package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

func readClipboardText() (string, error) {
	switch runtime.GOOS {
	case "windows":
		out, err := exec.Command("powershell", "-NoProfile", "-STA", "-Command",
			"Get-Clipboard -Raw -ErrorAction SilentlyContinue").Output()
		if err != nil {
			return "", err
		}
		return strings.TrimRight(string(out), "\r\n"), nil
	case "linux":
		for _, cmd := range [][]string{{"wl-paste", "-n"}, {"xclip", "-o", "-selection", "clipboard"}} {
			out, err := exec.Command(cmd[0], cmd[1:]...).Output()
			if err == nil {
				return strings.TrimSpace(string(out)), nil
			}
		}
		return "", fmt.Errorf("no clipboard tool found (need wl-paste or xclip)")
	case "darwin":
		out, err := exec.Command("pbpaste").Output()
		if err != nil {
			return "", err
		}
		return strings.TrimSpace(string(out)), nil
	}
	return "", fmt.Errorf("unsupported platform")
}

func setClipboardText(text string) {
	switch runtime.GOOS {
	case "windows":
		cmd := exec.Command("powershell", "-NoProfile", "-STA", "-Command",
			"$t = [Console]::In.ReadToEnd(); Set-Clipboard -Value $t")
		cmd.Stdin = strings.NewReader(text)
		cmd.Run()
	case "linux":
		cmd := exec.Command("wl-copy")
		cmd.Stdin = strings.NewReader(text)
		if cmd.Run() != nil {
			cmd = exec.Command("xclip", "-selection", "clipboard")
			cmd.Stdin = strings.NewReader(text)
			cmd.Run()
		}
	case "darwin":
		cmd := exec.Command("pbcopy")
		cmd.Stdin = strings.NewReader(text)
		cmd.Run()
	}
}

func clipboardWatchLoop(ctx context.Context, interval time.Duration, onChange func(string)) {
	last, err := readClipboardText()
	if err == nil && last != "" {
		onChange(last)
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			text, err := readClipboardText()
			if err != nil || text == last {
				continue
			}
			last = text
			if text != "" {
				onChange(text)
			}
		}
	}
}

var _ = os.Getenv
