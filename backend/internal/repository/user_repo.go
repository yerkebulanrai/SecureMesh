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
	// Мы используем RETURNING id, чтобы база сама сгенерировала UUID и вернула нам
	query := `
		INSERT INTO users (username_hash, public_identity_key)
		VALUES ($1, $2)
		RETURNING id, created_at
	`

	// Выполняем запрос
	err := r.db.QueryRow(ctx, query, user.UsernameHash, user.PublicIdentityKey).
		Scan(&user.ID, &user.CreatedAt)

	if err != nil {
		return fmt.Errorf("ошибка при создании пользователя: %w", err)
	}

	return nil
}

// GetPublicKey возвращает публичный ключ пользователя
func (r *UserRepository) GetPublicKey(ctx context.Context, userID string) (string, error) {
	var publicKey []byte
	query := `SELECT public_identity_key FROM users WHERE id = $1`
	
	err := r.db.QueryRow(ctx, query, userID).Scan(&publicKey)
	if err != nil {
		return "", fmt.Errorf("пользователь не найден: %w", err)
	}
	
	// Мы храним как []byte, но отдадим как строку, так как клиент шлет строку при регистрации
	// В идеале всё хранить в bytea, но для простоты пока вернем как есть
	return string(publicKey), nil
}