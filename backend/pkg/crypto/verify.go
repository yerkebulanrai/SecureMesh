package crypto

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
)

// VerifySignature проверяет Ed25519 подпись
// publicKeyB64 — Base64 публичный ключ (32 байта)
// message — то, что подписывали
// signatureB64 — Base64 подпись (64 байта)
func VerifySignature(publicKeyB64 string, message []byte, signatureB64 string) error {
	// 1. Декодируем публичный ключ
	publicKeyBytes, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return fmt.Errorf("invalid public key encoding: %w", err)
	}

	if len(publicKeyBytes) != ed25519.PublicKeySize {
		return fmt.Errorf("invalid public key size: got %d, want %d", len(publicKeyBytes), ed25519.PublicKeySize)
	}

	// 2. Декодируем подпись
	signatureBytes, err := base64.StdEncoding.DecodeString(signatureB64)
	if err != nil {
		return fmt.Errorf("invalid signature encoding: %w", err)
	}

	if len(signatureBytes) != ed25519.SignatureSize {
		return fmt.Errorf("invalid signature size: got %d, want %d", len(signatureBytes), ed25519.SignatureSize)
	}

	// 3. Проверяем подпись
	if !ed25519.Verify(publicKeyBytes, message, signatureBytes) {
		return fmt.Errorf("signature verification failed")
	}

	return nil
}
