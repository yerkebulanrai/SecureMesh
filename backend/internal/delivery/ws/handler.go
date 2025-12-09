package ws

import (
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/labstack/echo/v4"
	"google.golang.org/protobuf/proto"

	"github.com/yerkebulanrai/securemesh/backend/internal/repository"
	"github.com/yerkebulanrai/securemesh/backend/pkg/auth"
	pb "github.com/yerkebulanrai/securemesh/backend/pkg/proto"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WebSocketHandler struct {
	msgRepo *repository.MessageRepository
	clients map[string]*websocket.Conn
	mutex   sync.Mutex
}

func NewWebSocketHandler(repo *repository.MessageRepository) *WebSocketHandler {
	return &WebSocketHandler{
		msgRepo: repo,
		clients: make(map[string]*websocket.Conn),
	}
}

func (h *WebSocketHandler) Handle(c echo.Context) error {
	// ===== ИЗМЕНЕНИЕ: Теперь берём токен вместо userID =====
	token := c.QueryParam("token")
	if token == "" {
		return c.String(http.StatusUnauthorized, "token is required")
	}

	// Валидируем JWT и извлекаем userID
	userID, err := auth.ValidateToken(token)
	if err != nil {
		log.Printf("❌ Invalid token: %v", err)
		return c.String(http.StatusUnauthorized, "invalid or expired token")
	}
	// ========================================================

	ws, err := upgrader.Upgrade(c.Response(), c.Request(), nil)
	if err != nil {
		return err
	}

	h.mutex.Lock()
	h.clients[userID] = ws
	h.mutex.Unlock()

	log.Printf("👤 Пользователь подключился: %s", userID)

	defer func() {
		h.mutex.Lock()
		delete(h.clients, userID)
		h.mutex.Unlock()
		ws.Close()
		log.Printf("👤 Пользователь отключился: %s", userID)
	}()

	for {
		_, msgData, err := ws.ReadMessage()
		if err != nil {
			break
		}

		var protoMsg pb.WebSocketMessage
		if err := proto.Unmarshal(msgData, &protoMsg); err != nil {
			continue
		}

		// sender_id устанавливается сервером из JWT — нельзя подделать!
		protoMsg.SenderId = userID

		if protoMsg.Type == pb.WebSocketMessage_TEXT_MESSAGE {
			go h.msgRepo.Save(c.Request().Context(), &protoMsg)
		}

		if protoMsg.RecipientId != "" {
			h.sendToUser(protoMsg.RecipientId, msgData)
		} else {
			h.sendToUser(userID, msgData)
		}
	}

	return nil
}

func (h *WebSocketHandler) sendToUser(recipientID string, data []byte) {
	h.mutex.Lock()
	targetConn, ok := h.clients[recipientID]
	h.mutex.Unlock()

	if ok {
		err := targetConn.WriteMessage(websocket.BinaryMessage, data)
		if err != nil {
			log.Printf("❌ Ошибка отправки юзеру %s: %v", recipientID, err)
		}
	} else {
		log.Printf("💤 Юзер %s офлайн", recipientID)
	}
}