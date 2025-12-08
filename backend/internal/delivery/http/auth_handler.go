package http

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/yerkebulanrai/securemesh/backend/internal/domain"
	"github.com/yerkebulanrai/securemesh/backend/internal/repository"
)

type AuthHandler struct {
	userRepo *repository.UserRepository
}

func NewAuthHandler(repo *repository.UserRepository) *AuthHandler {
	return &AuthHandler{userRepo: repo}
}

// RegisterRequest - структура входящего JSON
type RegisterRequest struct {
	Username  string `json:"username"`
	PublicKey string `json:"public_key"` // Пока принимаем как строку для теста
}

// Register - метод обработки POST /register
func (h *AuthHandler) Register(c echo.Context) error {
	var req RegisterRequest
	
	// 1. Парсим JSON
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Неверный формат JSON"})
	}

	// 2. Создаем модель пользователя
	// В будущем здесь будет хэширование Argon2, пока просто берем имя как есть
	user := domain.User{
		UsernameHash:      req.Username, 
		PublicIdentityKey: []byte(req.PublicKey), // Конвертируем строку в байты
	}

	// 3. Сохраняем в базу
	err := h.userRepo.CreateUser(c.Request().Context(), &user)
	if err != nil {
		c.Logger().Error(err)
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Ошибка сохранения в БД (возможно, такой юзер уже есть)"})
	}

	// 4. Возвращаем успешный ответ с ID
	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status":  "created",
		"user_id": user.ID,
	})
}

// GetKey - отдает публичный ключ
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