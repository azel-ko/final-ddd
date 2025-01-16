FROM golang:1.23-alpine as builder

WORKDIR /app
COPY .. .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd

FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/main .
COPY --from=builder /app/configs ./configs

EXPOSE 9999
CMD ["/app/main"]