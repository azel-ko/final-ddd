FROM golang:1.21-alpine as builder

WORKDIR /app
COPY .. .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/api

FROM alpine:3.14
WORKDIR /app
COPY --from=builder /app/main .
COPY --from=builder /app/configs ./configs

EXPOSE 8080
CMD ["./main"]