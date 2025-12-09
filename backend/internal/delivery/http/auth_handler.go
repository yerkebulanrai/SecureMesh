package http

import (
	"fmt"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/yerkebulanrai/securemesh/backend/internal/domain"
	"github.com/yerkebulanrai/securemesh/backend/internal/repository"
	"github.com/yerkebulanrai/securemesh/backend/pkg/auth"
	"github.com/yerkebulanrai/securemesh/backend/pkg/crypto"
)

type AuthHandler struct {
	userRepo *repository.UserRepository
}

func NewAuthHandler(repo *repository.UserRepository) *AuthHandler {
	return &AuthHandler{userRepo: repo}
}

// ===== REGISTER =====

type RegisterRequest struct {
	Username   string `json:"username"`
	PublicKey  string `json:"public_key"`  // Curve25519 для шифрования
	SigningKey string `json:"signing_key"` // Ed25519 для подписей
}

func (h *AuthHandler) Register(c echo.Context) error {
	var req RegisterRequest

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Неверный формат JSON"})
	}

	// Валидация
	if req.Username == "" || req.PublicKey == "" || req.SigningKey == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "username, public_key и signing_key обязательны",
		})
	}

	user := domain.User{
		UsernameHash:      req.Username, // TODO: Argon2 хэш
		PublicIdentityKey: []byte(req.PublicKey),
		PublicSigningKey:  []byte(req.SigningKey),
	}

	err := h.userRepo.CreateUser(c.Request().Context(), &user)
	if err != nil {
		c.Logger().Error(err)
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Ошибка сохранения (возможно, юзер уже существует)",
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status":  "created",
		"user_id": user.ID,
	})
}

// ===== GET KEY =====

func (h *AuthHandler) GetKey(c echo.Context) error {
	userID := c.Param("id")
	if userID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "id is required"})
	}

	key, err := h.userRepo.GetPublicKey(c.Request().Context(), userID)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "User not found"})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"user_id":    userID,
		"public_key": key,
	})
}

// ===== GET TOKEN (NEW!) =====

type TokenRequest struct {
	UserID    string `json:"user_id"`
	Timestamp int64  `json:"timestamp"` // Unix timestamp
	Signature string `json:"signature"` // Base64 Ed25519 подпись
}

func (h *AuthHandler) GetToken(c echo.Context) error {
	var req TokenRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request"})
	}

	// 1. Проверяем timestamp (±5 минут)
	now := time.Now().Unix()
	diff := now - req.Timestamp
	if diff < 0 {
		diff = -diff
	}
	if diff > 300 {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "timestamp expired (must be within 5 minutes)",
		})
	}

	// 2. Получаем signing key из БД
	signingKey, err := h.userRepo.GetSigningKey(c.Request().Context(), req.UserID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}

	// 3. Формируем сообщение для проверки подписи
	// Подписываем: "securemesh:auth:{user_id}:{timestamp}"
	message := fmt.Sprintf("securemesh:auth:%s:%d", req.UserID, req.Timestamp)

	// 4. Проверяем подпись
	err = crypto.VerifySignature(signingKey, []byte(message), req.Signature)
	if err != nil {
		c.Logger().Error("Signature verification failed: ", err)
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid signature"})
	}

	// 5. Генерируем JWT
	token, err := auth.GenerateToken(req.UserID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "token generation failed"})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"token":      token,
		"expires_in": "900",
	})
}