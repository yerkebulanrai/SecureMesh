package ws

import (
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/labstack/echo/v4"
	"google.golang.org/protobuf/proto"

	"github.com/yerkebulanrai/securemesh/backend/internal/repository"
	pb "github.com/yerkebulanrai/securemesh/backend/pkg/proto"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Теперь храним маппинг: UserID -> WebSocket
type WebSocketHandler struct {
	msgRepo *repository.MessageRepository
	// Было: clients map[*websocket.Conn]bool
	clients map[string]*websocket.Conn // Стало: ID -> Conn
	mutex   sync.Mutex
}

func NewWebSocketHandler(repo *repository.MessageRepository) *WebSocketHandler {
	return &WebSocketHandler{
		msgRepo: repo,
		clients: make(map[string]*websocket.Conn),
	}
}

func (h *WebSocketHandler) Handle(c echo.Context) error {
	// 1. Получаем User ID из параметров подключения
	// Клиент будет стучаться так: ws://host/ws?userID=...
	userID := c.QueryParam("userID")
	if userID == "" {
		return c.String(http.StatusBadRequest, "userID is required")
	}

	ws, err := upgrader.Upgrade(c.Response(), c.Request(), nil)
	if err != nil {
		return err
	}

	// 2. Регистрируем конкретного пользователя
	h.mutex.Lock()
	h.clients[userID] = ws
	h.mutex.Unlock()

	log.Printf("👤 Пользователь подключился: %s", userID)

	defer func() {
		h.mutex.Lock()
		delete(h.clients, userID) // Удаляем по ID
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

		// ВАЖНО: Принудительно ставим sender_id, чтобы клиент не мог подделать его
		protoMsg.SenderId = userID

		// Сохраняем в БД
		if protoMsg.Type == pb.WebSocketMessage_TEXT_MESSAGE {
			// Тут можно добавить проверку: если recipient_id пустой — ошибка
			go h.msgRepo.Save(c.Request().Context(), &protoMsg)
		}

		// 3. Маршрутизация (Routing)
		if protoMsg.RecipientId != "" {
			// Если указан получатель — отправляем только ему
			h.sendToUser(protoMsg.RecipientId, msgData)
		} else {
			// Если не указан — можно оставить Broadcast для тестов, или запретить
			// Пока оставим эхо отправителю для теста
			h.sendToUser(userID, msgData) 
		}
	}

	return nil
}

// Функция отправки конкретному юзеру
func (h *WebSocketHandler) sendToUser(recipientID string, data []byte) {
	h.mutex.Lock()
	targetConn, ok := h.clients[recipientID]
	h.mutex.Unlock()

	if ok {
		// Получатель онлайн — отправляем
		// Используем BinaryMessage (2), так как это Protobuf
		err := targetConn.WriteMessage(websocket.BinaryMessage, data)
		if err != nil {
			log.Printf("❌ Ошибка отправки юзеру %s: %v", recipientID, err)
		}
	} else {
		log.Printf("💤 Юзер %s офлайн (сообщение сохранено в БД, доставим потом)", recipientID)
		// Здесь в будущем будет логика Push-уведомлений
	}
}