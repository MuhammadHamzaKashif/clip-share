package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
)

type WireMessage struct {
	Version    int                    `json:"v"`
	Type       string                 `json:"type"`
	DeviceID   string                 `json:"deviceId"`
	Nonce      string                 `json:"nonce,omitempty"`
	Ciphertext string                 `json:"ciphertext,omitempty"`
	Data       map[string]interface{} `json:"data,omitempty"`
}

func (m WireMessage) toJSON() []byte {
	b, _ := json.Marshal(m)
	return b
}

type SessionCrypto struct {
	key []byte
}

func newSessionCrypto(key []byte) *SessionCrypto {
	return &SessionCrypto{key: key}
}

func (c *SessionCrypto) seal(msgType, deviceID string, payload map[string]interface{}) WireMessage {
	nonce := make([]byte, 12)
	rand.Read(nonce)
	plain, _ := json.Marshal(payload)
	aad := []byte(msgType + "|" + deviceID)
	block, _ := aes.NewCipher(c.key)
	gcm, _ := cipher.NewGCM(block)
	sealed := gcm.Seal(nil, nonce, plain, aad)
	return WireMessage{
		Version:    1,
		Type:       msgType,
		DeviceID:   deviceID,
		Nonce:      base64.StdEncoding.EncodeToString(nonce),
		Ciphertext: base64.StdEncoding.EncodeToString(sealed),
	}
}

func (c *SessionCrypto) open(m WireMessage) (map[string]interface{}, error) {
	nonce, err := base64.StdEncoding.DecodeString(m.Nonce)
	if err != nil {
		return nil, err
	}
	sealed, err := base64.StdEncoding.DecodeString(m.Ciphertext)
	if err != nil {
		return nil, err
	}
	aad := []byte(m.Type + "|" + m.DeviceID)
	block, err := aes.NewCipher(c.key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	plain, err := gcm.Open(nil, nonce, sealed, aad)
	if err != nil {
		return nil, err
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(plain, &payload); err != nil {
		return nil, err
	}
	return payload, nil
}
