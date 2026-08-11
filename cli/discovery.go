package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	"github.com/grandcat/zeroconf"
)

const serviceType = "_clipshare._tcp"

type DiscoveredDevice struct {
	ID      string
	Name    string
	KeyHash string
	Addr    string
	Port    int
}

func usableInterfaces() []net.Interface {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}
	var usable []net.Interface
	for _, i := range ifaces {
		if i.Flags&net.FlagUp == 0 || i.Flags&net.FlagLoopback != 0 {
			continue
		}
		if addrs, err := i.Addrs(); err == nil {
			for _, a := range addrs {
				if ip, ok := a.(*net.IPNet); ok && ip.IP.To4() != nil {
					usable = append(usable, i)
					break
				}
			}
		}
	}
	return usable
}

func announce(ctx context.Context, id Identity, name string, port int, txt map[string]string) (*zeroconf.Server, error) {
	text := make([]string, 0, len(txt))
	for k, v := range txt {
		text = append(text, fmt.Sprintf("%s=%s", k, v))
	}
	server, err := zeroconf.Register(id.DeviceID, serviceType, "local.", port,
		text, usableInterfaces())
	if err != nil {
		return nil, err
	}
	go func() {
		<-ctx.Done()
		server.Shutdown()
	}()
	return server, nil
}

func browseDevices(ctx context.Context, seconds int, excludeSelf string) ([]DiscoveredDevice, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(seconds)*time.Second)
	defer cancel()
	results := make(chan *zeroconf.ServiceEntry, 16)
	resolver, err := zeroconf.NewResolver(
		zeroconf.SelectIPTraffic(zeroconf.IPv4),
		zeroconf.SelectIfaces(usableInterfaces()),
	)
	if err != nil {
		return nil, err
	}
	if err := resolver.Browse(ctx, serviceType, "local.", results); err != nil {
		return nil, err
	}
	seen := map[string]DiscoveredDevice{}
	for entry := range results {
		if entry.Instance == excludeSelf {
			continue
		}
		name := entry.Instance
		for _, t := range entry.Text {
			if strings.HasPrefix(t, "name=") {
				name = strings.TrimPrefix(t, "name=")
			}
		}
		keyHash := ""
		for _, t := range entry.Text {
			if strings.HasPrefix(t, "key=") {
				keyHash = strings.TrimPrefix(t, "key=")
			}
		}
		if len(entry.AddrIPv4) == 0 {
			continue
		}
		seen[entry.Instance] = DiscoveredDevice{
			ID:      entry.Instance,
			Name:    name,
			KeyHash: keyHash,
			Addr:    entry.AddrIPv4[0].String(),
			Port:    entry.Port,
		}
	}
	out := make([]DiscoveredDevice, 0, len(seen))
	for _, d := range seen {
		out = append(out, d)
	}
	return out, nil
}

func logf(format string, args ...any) {
	log.Printf("[clipshare] "+format, args...)
}

var _ = fmt.Sprintf
