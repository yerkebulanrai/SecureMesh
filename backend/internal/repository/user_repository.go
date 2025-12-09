package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/yerkebulanrai/securemesh/backend/internal/domain"
)

type UserRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

// CreateUser сохраняет пользователя в БД
func (r *UserRepository) CreateUser(ctx context.Context, user *domain.User) error {
	query := `
		INSERT INTO users (username_hash, public_identity_key, public_signing_key)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`

	err := r.db.QueryRow(ctx, query, 
		user.UsernameHash, 
		user.PublicIdentityKey,
		user.PublicSigningKey,
	).Scan(&user.ID, &user.CreatedAt)

	if err != nil {
		return fmt.Errorf("ошибка при создании пользователя: %w", err)
	}

	return nil
}

// GetPublicKey возвращает публичный ключ шифрования (Curve25519)
func (r *UserRepository) GetPublicKey(ctx context.Context, userID string) (string, error) {
	var publicKey []byte
	query := `SELECT public_identity_key FROM users WHERE id = $1`

	err := r.db.QueryRow(ctx, query, userID).Scan(&publicKey)
	if err != nil {
		return "", fmt.Errorf("пользователь не найден: %w", err)
	}

	return string(publicKey), nil
}

// GetSigningKey возвращает публичный ключ подписи (Ed25519)
func (r *UserRepository) GetSigningKey(ctx context.Context, userID string) (string, error) {
	var signingKey []byte
	query := `SELECT public_signing_key FROM users WHERE id = $1`

	err := r.db.QueryRow(ctx, query, userID).Scan(&signingKey)
	if err != nil {
		return "", fmt.Errorf("пользователь не найден: %w", err)
	}

	return string(signingKey), nil
}
