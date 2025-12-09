package domain

import (
	"time"
)

// User — основная модель пользователя
type User struct {
	ID                string    `json:"id"`
	UsernameHash      string    `json:"username_hash"`
	PublicIdentityKey []byte    `json:"public_identity_key"` // Curve25519 для ECDH
	PublicSigningKey  []byte    `json:"public_signing_key"`  // Ed25519 для подписей
	RegistrationLock  string    `json:"-"`
	CreatedAt         time.Time `json:"created_at"`
}