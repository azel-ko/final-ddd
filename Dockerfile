FROM docker.1ms.run/golang:1.23-alpine as builder

WORKDIR /app
COPY . .
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o main cmd/main.go

FROM docker.1ms.run/alpine:3.21
WORKDIR /app
COPY --from=builder /app/main .
COPY --from=builder /app/configs ./configs

EXPOSE 9999
CMD ["/app/main"]