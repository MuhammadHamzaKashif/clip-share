package main

import (
	"crypto/ecdh"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"golang.org/x/crypto/hkdf"
)

type Identity struct {
	DeviceID   string `json:"deviceId"`
	PrivateKey string `json:"privateKey"`
	PublicKey  string `json:"publicKey"`
}

type PairedDevice struct {
	DeviceID  string `json:"deviceId"`
	Name      string `json:"name"`
	PublicKey string `json:"publicKey"`
	KeyHash   string `json:"keyHash"`
	PairedAt  string `json:"pairedAt"`
}

type DevicesFile struct {
	Devices []PairedDevice `json:"devices"`
}

func configDir() (string, error) {
	base := os.Getenv("APPDATA")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "ClipShare", "cli"), nil
}

func loadJSON(path string, out any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	return json.Unmarshal(data, out)
}

func saveJSON(path string, v any) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o600)
}

func loadOrCreateIdentity() (Identity, error) {
	dir, err := configDir()
	if err != nil {
		return Identity{}, err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return Identity{}, err
	}
	path := filepath.Join(dir, "identity.json")
	var id Identity
	if err := loadJSON(path, &id); err != nil {
		return Identity{}, err
	}
	if id.DeviceID != "" {
		return id, nil
	}
	curve := ecdh.P256()
	key, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		return Identity{}, err
	}
	devID := make([]byte, 16)
	if _, err := rand.Read(devID); err != nil {
		return Identity{}, err
	}
	id = Identity{
		DeviceID:   hex.EncodeToString(devID),
		PrivateKey: base64.StdEncoding.EncodeToString(key.Bytes()),
		PublicKey:  base64.StdEncoding.EncodeToString(key.PublicKey().Bytes()),
	}
	if err := saveJSON(path, id); err != nil {
		return Identity{}, err
	}
	return id, nil
}

func loadDevices() ([]PairedDevice, error) {
	dir, err := configDir()
	if err != nil {
		return nil, err
	}
	var f DevicesFile
	if err := loadJSON(filepath.Join(dir, "devices.json"), &f); err != nil {
		return nil, err
	}
	return f.Devices, nil
}

func saveDevices(devices []PairedDevice) error {
	dir, err := configDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	return saveJSON(filepath.Join(dir, "devices.json"), DevicesFile{Devices: devices})
}

func addDevice(d PairedDevice) error {
	devices, err := loadDevices()
	if err != nil {
		return err
	}
	kept := devices[:0]
	for _, d2 := range devices {
		if d2.DeviceID != d.DeviceID {
			kept = append(kept, d2)
		}
	}
	kept = append(kept, d)
	return saveDevices(kept)
}

func findDeviceByKeyHash(keyHash string) (*PairedDevice, error) {
	devices, err := loadDevices()
	if err != nil {
		return nil, err
	}
	for i := range devices {
		if devices[i].KeyHash == keyHash {
			return &devices[i], nil
		}
	}
	return nil, nil
}

func decodePriv(b64 string) (*ecdh.PrivateKey, error) {
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return nil, err
	}
	return ecdh.P256().NewPrivateKey(raw)
}

func decodePub(b64 string) (*ecdh.PublicKey, error) {
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return nil, err
	}
	return ecdh.P256().NewPublicKey(raw)
}

func ecdhSecret(myPrivB64, peerPubB64 string) ([]byte, error) {
	priv, err := decodePriv(myPrivB64)
	if err != nil {
		return nil, err
	}
	pub, err := decodePub(peerPubB64)
	if err != nil {
		return nil, err
	}
	return priv.ECDH(pub)
}

func hkdfSha256(ikm []byte, length int, salt, info []byte) []byte {
	reader := hkdf.New(sha256.New, ikm, salt, info)
	out := make([]byte, length)
	if _, err := reader.Read(out); err != nil {
		panic(err)
	}
	return out
}

func hmacSha256(key, msg []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(msg)
	return h.Sum(nil)
}

func derivePairKey(myPriv, peerPub, code string) ([]byte, error) {
	shared, err := ecdhSecret(myPriv, peerPub)
	if err != nil {
		return nil, err
	}
	return hkdfSha256(shared, 32, []byte("clipshare-pair"), []byte(code)), nil
}

func deriveSessionKey(myPriv, peerPub string) ([]byte, error) {
	shared, err := ecdhSecret(myPriv, peerPub)
	if err != nil {
		return nil, err
	}
	return hkdfSha256(shared, 32, []byte("clipshare-session"), nil), nil
}

func proofOf(pairKey []byte) []byte {
	return hmacSha256(pairKey, []byte("clipshare-pair-proof"))
}

func keyHashOf(pubB64 string) string {
	raw, _ := base64.StdEncoding.DecodeString(pubB64)
	return fmt.Sprintf("%x", sha256.Sum256(raw))
}

func constantTimeEquals(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var diff byte
	for i := range a {
		diff |= a[i] ^ b[i]
	}
	return diff == 0
}
