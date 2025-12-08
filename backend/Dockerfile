# 1. Этап сборки (Builder)
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Копируем файлы зависимостей
COPY go.mod go.sum ./
RUN go mod download

# Копируем исходный код
COPY . .

# Собираем бинарный файл
RUN go build -o securemesh-api ./cmd/api/main.go

# 2. Финальный этап (Запуск)
FROM alpine:latest

WORKDIR /root/

# Копируем собранный файл из первого этапа
COPY --from=builder /app/securemesh-api .
# Копируем конфиги/миграции если они нужны (пока нет, они в коде)

# Открываем порт
EXPOSE 8080

# Запускаем
CMD ["./securemesh-api"]