// pkg/auth/jwt.go
package auth

import (
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("invalid or expired token")
	jwtSecret       []byte
)

func init() {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "CHANGE_ME_IN_PRODUCTION" // fallback для dev
	}
	jwtSecret = []byte(secret)
}

type Claims struct {
	UserID string `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken создаёт JWT на 15 минут
func GenerateToken(userID string) (string, error) {
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "securemesh",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// ValidateToken проверяет токен и возвращает user_id
func ValidateToken(tokenString string) (string, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return jwtSecret, nil
	})

	if err != nil {
		return "", ErrInvalidToken
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims.UserID, nil
	}

	return "", ErrInvalidToken
}