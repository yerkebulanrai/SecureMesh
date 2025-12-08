package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPostgresDB создает пул соединений к PostgreSQL
func NewPostgresDB(host, port, user, password, dbname string) (*pgxpool.Pool, error) {
	// Формируем строку подключения (DSN)
	// Важно: sslmode=disable для локальной разработки
	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		user, password, host, port, dbname)

	// Настройка конфигурации пула
	config, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("ошибка парсинга конфига БД: %w", err)
	}

	// Настройки таймаутов (важно для Production)
	config.MaxConns = 25                       // Максимум 25 соединений
	config.MinConns = 2                        // Минимум 2 всегда держим открытыми
	config.MaxConnLifetime = 5 * time.Minute   // Пересоздавать соединения каждые 5 минут
	config.MaxConnIdleTime = 30 * time.Minute

	// Создаем пул
	pool, err := pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		return nil, fmt.Errorf("не удалось создать пул подключений: %w", err)
	}

	// Проверяем, что база реально отвечает (Ping)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("база данных недоступна (ping failed): %w", err)
	}

	log.Println("✅ Успешное подключение к PostgreSQL")
	return pool, nil
}