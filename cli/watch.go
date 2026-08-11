package main

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

type peerConn struct {
	device *PairedDevice
	crypto *SessionCrypto
	ws     *websocket.Conn
	name   string
	mu     sync.Mutex
}

func (p *peerConn) write(msg WireMessage) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.ws.WriteJSON(msg)
}

func nameOf(id Identity) string {
	if name := os.Getenv("CLIPSHARE_NAME"); name != "" {
		return name
	}
	return "terminal"
}

func watchCommand(id Identity) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	server := &http.Server{Addr: ":48901"}
	upgrader := websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
	incoming := make(chan map[string]interface{}, 16)
	peers := map[string]*peerConn{}
	var peersMu sync.Mutex

	mux := http.NewServeMux()
	mux.HandleFunc("/key", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"publicKey": id.PublicKey, "name": nameOf(id)})
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ws, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		go handleServerConn(ctx, id, ws, incoming)
	})
	go server.ListenAndServe()
	defer server.Close()

	announce(ctx, id, nameOf(id), 48901, map[string]string{
		"name": nameOf(id), "ver": "0", "key": keyHashOf(id.PublicKey),
	})

	seen := map[string]bool{}

	sendItem := func(text string) {
		itemID := fmt.Sprintf("%x", sha256.Sum256([]byte(text)))
		if seen[itemID] {
			return
		}
		seen[itemID] = true
		if len(seen) > 500 {
			for k := range seen {
				delete(seen, k)
				break
			}
		}
		fmt.Printf("> this device: %s\n", text)
		payload := map[string]interface{}{
			"itemId": itemID, "kind": "text", "payload": text,
			"ts": time.Now().UnixMilli(),
		}
		peersMu.Lock()
		for _, p := range peers {
			p.write(p.crypto.seal("clipboard_update", id.DeviceID, payload))
		}
		peersMu.Unlock()
	}

	go clipboardWatchLoop(ctx, 1*time.Second, sendItem)
	go discoverLoop(ctx, id, &peers, &peersMu, incoming)

	for {
		select {
		case <-ctx.Done():
			return nil
		case item := <-incoming:
			itemID := str(item, "itemId")
			if itemID == "" || seen[itemID] {
				continue
			}
			seen[itemID] = true
			payload := str(item, "payload")
			source := str(item, "source")
			fmt.Printf("> %s: %s\n", source, payload)
			setClipboardText(payload)
		}
	}
}

func handleServerConn(ctx context.Context, id Identity, ws *websocket.Conn, incoming chan map[string]interface{}) {
	defer ws.Close()
	ws.SetReadDeadline(time.Now().Add(30 * time.Second))
	peer := &peerConn{ws: ws}
	for {
		var msg WireMessage
		if err := ws.ReadJSON(&msg); err != nil {
			return
		}
		if msg.Type == "pair_request" {
			peerPub := str(msg.Data, "publicKey")
			proof := str(msg.Data, "proof")
			if peerPub == "" || proof == "" {
				continue
			}
			key, err := derivePairKey(id.PrivateKey, peerPub, "")
			if err != nil || !constantTimeEquals(proofOf(key), mustB64(proof)) {
				peer.write(WireMessage{Version: 1, Type: "pair_reject", DeviceID: id.DeviceID,
					Data: map[string]interface{}{"reason": "bad_proof"}})
				return
			}
			peer.write(WireMessage{Version: 1, Type: "pair_confirm", DeviceID: id.DeviceID,
				Data: map[string]interface{}{
					"publicKey": id.PublicKey,
					"name":      nameOf(id),
					"proof":     base64.StdEncoding.EncodeToString(proofOf(key)),
				}})
			continue
		}
		if msg.Type != "hello" || peer.crypto != nil {
			continue
		}
		known, err := findDeviceByKeyHash(keyHashOf(""))
		if err != nil {
			return
		}
		if known == nil {
			ws.Close()
			return
		}
		key, err := deriveSessionKey(id.PrivateKey, known.PublicKey)
		if err != nil {
			return
		}
		peer.crypto = newSessionCrypto(key)
		payload, err := peer.crypto.open(msg)
		if err != nil {
			ws.Close()
			return
		}
		peer.device = known
		peer.name = str(payload, "name")
		peer.write(peer.crypto.seal("hello", id.DeviceID, map[string]interface{}{"name": nameOf(id)}))
		ws.SetReadDeadline(time.Time{})
		watchPeer(ctx, peer, incoming)
		return
	}
}

func watchPeer(ctx context.Context, peer *peerConn, incoming chan map[string]interface{}) {
	for {
		var msg WireMessage
		if err := peer.ws.ReadJSON(&msg); err != nil {
			return
		}
		if msg.Type != "clipboard_update" {
			continue
		}
		payload, err := peer.crypto.open(msg)
		if err != nil {
			continue
		}
		payload["source"] = peer.name
		select {
		case incoming <- payload:
		case <-ctx.Done():
			return
		}
	}
}

func discoverLoop(ctx context.Context, id Identity, peers *map[string]*peerConn, mu *sync.Mutex, incoming chan map[string]interface{}) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(5 * time.Second):
		}
		devices, err := browseDevices(ctx, 2, id.DeviceID)
		if err != nil {
			continue
		}
		for _, d := range devices {
			if d.KeyHash == "" {
				continue
			}
			mu.Lock()
			existing := (*peers)[d.ID]
			mu.Unlock()
			if existing != nil {
				continue
			}
			known, err := findDeviceByKeyHash(d.KeyHash)
			if err != nil || known == nil {
				continue
			}
			key, err := deriveSessionKey(id.PrivateKey, known.PublicKey)
			if err != nil {
				continue
			}
			ws, _, err := websocket.DefaultDialer.Dial(fmt.Sprintf("ws://%s:%d", d.Addr, d.Port), nil)
			if err != nil {
				continue
			}
			crypto := newSessionCrypto(key)
			if err := ws.WriteJSON(crypto.seal("hello", id.DeviceID, map[string]interface{}{"name": nameOf(id)})); err != nil {
				ws.Close()
				continue
			}
			ws.SetReadDeadline(time.Now().Add(10 * time.Second))
			var msg WireMessage
			if err := ws.ReadJSON(&msg); err != nil || msg.Type != "hello" {
				ws.Close()
				continue
			}
			payload, err := crypto.open(msg)
			if err != nil {
				ws.Close()
				continue
			}
			ws.SetReadDeadline(time.Time{})
			peer := &peerConn{device: known, crypto: crypto, ws: ws, name: str(payload, "name")}
			mu.Lock()
			(*peers)[d.ID] = peer
			mu.Unlock()
			logf("connected to %s", peer.name)
			go watchPeer(ctx, peer, incoming)
		}
	}
}
