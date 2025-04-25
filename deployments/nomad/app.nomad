job "app" {
  datacenters = ["dc1"]
  type = "service"

  group "app" {
    count = 1

    network {
      port "http" {
        to = 9999
      }
    }

    service {
      name = "app"
      port = "http"

      # 添加域名相关的标签
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.app.entrypoints=websecure",
        "traefik.http.routers.app.rule=Host(`${DOMAIN_NAME}`) && PathPrefix(`/app`)",
        "traefik.http.middlewares.app-strip.stripprefix.prefixes=/app",
        "traefik.http.routers.app.middlewares=app-strip",
        "traefik.http.routers.app.priority=2",
        "traefik.http.routers.app.tls.certresolver=leresolver"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "go-app:latest"
        ports = ["http"]
        volumes = [
          "local/logs:/app/logs"
        ]
      }

      # 使用模板获取服务地址
      template {
        data = <<EOF
# 服务发现配置
MYSQL_ADDR={{ range service "mysql" }}{{ .Address }}:{{ .Port }}{{ end }}
REDIS_ADDR={{ range service "redis" }}{{ .Address }}:{{ .Port }}{{ end }}
RABBITMQ_ADDR={{ range service "rabbitmq" }}{{ .Address }}:{{ .Port }}{{ end }}
EOF
        destination = "local/service-discovery.env"
        env = true
      }

      env {
        # 环境变量配置，根据实际需要设置
        DATABASE_SERVICE = "${DATABASE_SERVICE}"
        DOMAIN_NAME = "${DOMAIN_NAME}"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      logs {
        max_files     = 10
        max_file_size = 10
      }
    }

    ephemeral_disk {
      size = 300
    }
  }
}
