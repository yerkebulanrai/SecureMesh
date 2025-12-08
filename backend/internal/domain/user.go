package domain

import (
	"time"
)

// User - основная модель пользователя
type User struct {
	ID                 string    `json:"id"`                   // UUID
	UsernameHash       string    `json:"username_hash"`        // Argon2 хэш логина
	PublicIdentityKey  []byte    `json:"public_identity_key"`  // Публичный ключ (Identity Key)
	RegistrationLock   string    `json:"-"`                    // Хэш PIN-кода (не отдаем в JSON)
	CreatedAt          time.Time `json:"created_at"`
}