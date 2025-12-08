package main

import (
	"context"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	// Импортируем наши новые пакеты
	"github.com/yerkebulanrai/securemesh/backend/internal/delivery/http"
	"github.com/yerkebulanrai/securemesh/backend/internal/repository"
	"github.com/yerkebulanrai/securemesh/backend/pkg/database"
	"github.com/yerkebulanrai/securemesh/backend/internal/delivery/ws"
)

func main() {
	// 1. Загрузка .env
	if err := godotenv.Load("../.env"); err != nil {
		log.Println("⚠️ .env файл не найден")
	}

	// 2. БД
	dbPool, err := database.NewPostgresDB(
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_NAME"),
	)
	if err != nil {
		log.Fatalf("❌ Ошибка БД: %v", err)
	}
	defer dbPool.Close()

	// Миграции
	if err := database.RunMigrations(dbPool); err != nil {
		log.Fatalf("❌ Ошибка миграции: %v", err)
	}

	// === NEW: Инициализация слоев ===
	userRepo := repository.NewUserRepository(dbPool)
	authHandler := http.NewAuthHandler(userRepo)
	// ================================

	// === NEW: Инициализация WS Handler ===
	msgRepo := repository.NewMessageRepository(dbPool)
	wsHandler := ws.NewWebSocketHandler(msgRepo)
	// =====================================

	// 3. Echo
	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.GET("/ws", wsHandler.Handle)

	// === NEW: Роуты ===
	e.POST("/register", authHandler.Register)
	// ==================

	e.GET("/keys/:id", authHandler.GetKey)
	
	// Тест
	e.GET("/health", func(c echo.Context) error {
		err := dbPool.Ping(context.Background())
		if err != nil {
			return c.JSON(500, map[string]string{"status": "error"})
		}
		return c.JSON(200, map[string]string{"status": "ok"})
	})

	// 4. Старт
	port := os.Getenv("SERVER_PORT")
	if port == "" {
		port = "8080"
	}
	e.Logger.Fatal(e.Start(":" + port))
}