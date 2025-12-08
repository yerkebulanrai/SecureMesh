package database

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

func RunMigrations(pool *pgxpool.Pool) error {
	const createTables = `
	-- Таблица пользователей (уже была)
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		username_hash TEXT NOT NULL UNIQUE,
		public_identity_key BYTEA NOT NULL,
		registration_lock_hash TEXT,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		deleted_at TIMESTAMPTZ
	);
	CREATE INDEX IF NOT EXISTS idx_users_username_hash ON users(username_hash);

	-- NEW: Таблица сообщений
	CREATE TABLE IF NOT EXISTS messages (
		id UUID PRIMARY KEY, -- ID берем из Protobuf (генерирует клиент)
		type INT NOT NULL,
		payload BYTEA NOT NULL, -- Зашифрованный контент
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		-- Позже добавим sender_id и recipient_id, когда сделаем авторизацию в сокете
	);
	`

	_, err := pool.Exec(context.Background(), createTables)
	if err != nil {
		return err
	}

	log.Println("📦 Миграции БД применены успешно")
	return nil
}