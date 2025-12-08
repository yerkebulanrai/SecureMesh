package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	pb "github.com/yerkebulanrai/securemesh/backend/pkg/proto"
)

type MessageRepository struct {
	db *pgxpool.Pool
}

func NewMessageRepository(db *pgxpool.Pool) *MessageRepository {
	return &MessageRepository{db: db}
}

// Save сохраняет сообщение из Protobuf в Postgres
func (r *MessageRepository) Save(ctx context.Context, msg *pb.WebSocketMessage) error {
	query := `
		INSERT INTO messages (id, type, payload, created_at)
		VALUES ($1, $2, $3, $4)
	`
	
	// Конвертируем Unix timestamp (int64) в time.Time
	createdAt := time.Unix(msg.Timestamp, 0)

	_, err := r.db.Exec(ctx, query, msg.Id, msg.Type, msg.Payload, createdAt)
	if err != nil {
		return fmt.Errorf("ошибка сохранения сообщения: %w", err)
	}
	
	return nil
}