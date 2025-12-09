package database

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

func RunMigrations(pool *pgxpool.Pool) error {
	const createTables = `
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		username_hash TEXT NOT NULL UNIQUE,
		public_identity_key BYTEA NOT NULL,
		public_signing_key BYTEA,
		registration_lock_hash TEXT,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		deleted_at TIMESTAMPTZ
	);
	CREATE INDEX IF NOT EXISTS idx_users_username_hash ON users(username_hash);

	DO $$ 
	BEGIN 
		IF NOT EXISTS (
			SELECT 1 FROM information_schema.columns 
			WHERE table_name = 'users' AND column_name = 'public_signing_key'
		) THEN 
			ALTER TABLE users ADD COLUMN public_signing_key BYTEA;
		END IF;
	END $$;

	CREATE TABLE IF NOT EXISTS messages (
		id UUID PRIMARY KEY,
		type INT NOT NULL,
		payload BYTEA NOT NULL,
		sender_id UUID REFERENCES users(id),
		recipient_id UUID REFERENCES users(id),
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
	CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at);
	`

	_, err := pool.Exec(context.Background(), createTables)
	if err != nil {
		return err
	}

	log.Println("📦 Миграции БД применены успешно")
	return nil
}
