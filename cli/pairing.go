package main

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

const pairCodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

var stdinReader = bufio.NewReader(os.Stdin)

func generateCode() string {
	b := make([]byte, 6)
	rand.Read(b)
	out := make([]byte, 6)
	for i := range b {
		out[i] = pairCodeAlphabet[int(b[i])%len(pairCodeAlphabet)]
	}
	return string(out)
}

func fetchKey(host string, port int) (map[string]interface{}, error) {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://%s:%d/key", host, port))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("key endpoint returned %d", resp.StatusCode)
	}
	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return nil, err
	}
	return body, nil
}

func hostPairing(id Identity, name string, port int) error {
	code := generateCode()
	fmt.Printf("code: %s\n", code)
	fmt.Printf("waiting for a device to enter it...\n")
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	server, err := announce(ctx, id, name, port, map[string]string{
		"name": name, "ver": "0", "key": keyHashOf(id.PublicKey),
	})
	if err != nil {
		return err
	}
	defer server.Shutdown()
	mux := http.NewServeMux()
	httpServer := &http.Server{Addr: fmt.Sprintf(":%d", port), Handler: mux}
	done := make(chan *PairedDevice, 1)
	mux.HandleFunc("/key", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"publicKey": id.PublicKey, "name": name})
	})
	var upgrader = websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ws, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer ws.Close()
		for {
			_, raw, err := ws.ReadMessage()
			if err != nil {
				return
			}
			var msg WireMessage
			if err := json.Unmarshal(raw, &msg); err != nil || msg.Type != "pair_request" {
				continue
			}
			data := msg.Data
			peerPub := str(data, "publicKey")
			proof := str(data, "proof")
			code2 := code
			if peerPub == "" || proof == "" {
				continue
			}
			pairKey, err := derivePairKey(id.PrivateKey, peerPub, code2)
			if err != nil || !constantTimeEquals(proofOf(pairKey), mustB64(proof)) {
				ws.WriteJSON(WireMessage{Version: 1, Type: "pair_reject", DeviceID: id.DeviceID,
					Data: map[string]interface{}{"reason": "bad_proof"}})
				return
			}
			ws.WriteJSON(WireMessage{Version: 1, Type: "pair_confirm", DeviceID: id.DeviceID,
				Data: map[string]interface{}{
					"publicKey": id.PublicKey,
					"name":      name,
					"proof":     base64.StdEncoding.EncodeToString(proofOf(pairKey)),
				}})
			device := &PairedDevice{
				DeviceID:  msg.DeviceID,
				Name:      str(data, "name"),
				PublicKey: peerPub,
				KeyHash:   str(data, "keyHash"),
				PairedAt:  time.Now().UTC().Format(time.RFC3339),
			}
			done <- device
			return
		}
	})
	go httpServer.ListenAndServe()
	select {
	case device := <-done:
		httpServer.Close()
		if err := addDevice(*device); err != nil {
			return err
		}
		fmt.Printf("paired with %s (%s)\n", device.Name, device.DeviceID)
		return nil
	case <-time.After(2 * time.Minute):
		httpServer.Close()
		return fmt.Errorf("pairing timed out")
	}
}

func joinPairing(id Identity, name string, device DiscoveredDevice, code string) error {
	keyResp, err := fetchKey(device.Addr, device.Port)
	if err != nil {
		return err
	}
	peerPub := str(keyResp, "publicKey")
	if peerPub == "" {
		return fmt.Errorf("no public key in response")
	}
	pairKey, err := derivePairKey(id.PrivateKey, peerPub, code)
	if err != nil {
		return err
	}
	ws, _, err := websocket.DefaultDialer.Dial(fmt.Sprintf("ws://%s:%d", device.Addr, device.Port), nil)
	if err != nil {
		return err
	}
	defer ws.Close()
	ws.SetReadDeadline(time.Now().Add(15 * time.Second))
	req := WireMessage{Version: 1, Type: "pair_request", DeviceID: id.DeviceID,
		Data: map[string]interface{}{
			"name":      name,
			"publicKey": id.PublicKey,
			"keyHash":   keyHashOf(id.PublicKey),
			"proof":     base64.StdEncoding.EncodeToString(proofOf(pairKey)),
		}}
	if err := ws.WriteJSON(req); err != nil {
		return err
	}
	for {
		var msg WireMessage
		if err := ws.ReadJSON(&msg); err != nil {
			return err
		}
		if msg.Type == "pair_reject" {
			return fmt.Errorf("rejected: %s", str(msg.Data, "reason"))
		}
		if msg.Type != "pair_confirm" {
			continue
		}
		confirmPub := str(msg.Data, "publicKey")
		confirmProof := str(msg.Data, "proof")
		if confirmPub == "" || confirmProof == "" {
			return fmt.Errorf("bad pair_confirm")
		}
		if !constantTimeEquals(proofOf(pairKey), mustB64(confirmProof)) {
			return fmt.Errorf("confirm proof mismatch")
		}
		device := PairedDevice{
			DeviceID:  msg.DeviceID,
			Name:      str(msg.Data, "name"),
			PublicKey: confirmPub,
			KeyHash:   keyHashOf(confirmPub),
			PairedAt:  time.Now().UTC().Format(time.RFC3339),
		}
		if err := addDevice(device); err != nil {
			return err
		}
		fmt.Printf("paired with %s (%s)\n", device.Name, device.DeviceID)
		return nil
	}
}

func pickDevice(devices []DiscoveredDevice) (*DiscoveredDevice, error) {
	if len(devices) == 0 {
		return nil, fmt.Errorf("no devices found on this network")
	}
	for i, d := range devices {
		fmt.Printf("%d. %s (%s)\n", i+1, d.Name, d.Addr)
	}
	fmt.Print("pick a device: ")
	line, err := stdinReader.ReadString('\n')
	if err != nil {
		return nil, err
	}
	var idx int
	if _, err := fmt.Sscanf(strings.TrimSpace(line), "%d", &idx); err != nil || idx < 1 || idx > len(devices) {
		return nil, fmt.Errorf("invalid choice")
	}
	return &devices[idx-1], nil
}

func askCode() (string, error) {
	fmt.Print("enter the 6-character code: ")
	line, err := stdinReader.ReadString('\n')
	if err != nil {
		return "", err
	}
	code := strings.ToUpper(strings.TrimSpace(line))
	if len(code) != 6 {
		return "", fmt.Errorf("code must be 6 characters")
	}
	for _, c := range code {
		if !strings.ContainsRune(pairCodeAlphabet, c) {
			return "", fmt.Errorf("code has invalid characters")
		}
	}
	return code, nil
}

func pairCommand(id Identity, name string) error {
	fmt.Println("1. show my code")
	fmt.Println("2. enter a code")
	fmt.Print("choose: ")
	line, _ := stdinReader.ReadString('\n')
	switch strings.TrimSpace(line) {
	case "1":
		return hostPairing(id, name, 48901)
	case "2":
		devices, err := browseDevices(context.Background(), 4, id.DeviceID)
		if err != nil {
			return err
		}
		device, err := pickDevice(devices)
		if err != nil {
			return err
		}
		code, err := askCode()
		if err != nil {
			return err
		}
		return joinPairing(id, name, *device, code)
	default:
		return fmt.Errorf("invalid choice")
	}
}

func str(m map[string]interface{}, key string) string {
	if m == nil {
		return ""
	}
	v, _ := m[key].(string)
	return v
}

func mustB64(s string) []byte {
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}

var _ = io.Discard
