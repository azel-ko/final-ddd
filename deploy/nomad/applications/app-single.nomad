job "app" {
  datacenters = ["dc1"]
  type = "service"

  group "app" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "app"
      port = "http"

      check {
        name     = "app-health"
        type     = "http"
        path     = "/api/health"
        port     = "http"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "${APP_IMAGE}"
        ports = ["http"]
        force_pull = false

        mount {
          type   = "bind"
          source = "/opt/data/app"
          target = "/app/logs"
        }
      }

      # 服务发现配置 - 单机模式使用静态配置
      env {
        # 应用基本配置
        APP_ENV = "${APP_ENV}"
        APP_PORT = "8080"

        # 数据库配置 - 单机模式直接使用 localhost
        DB_TYPE = "postgres"
        DB_NAME = "${DB_NAME}"
        DB_USER = "${DB_USER}"
        DB_PASSWORD = "${DB_PASSWORD}"
        DATABASE_HOST = "localhost"
        DATABASE_PORT = "5432"

        # JWT 配置
        JWT_SECRET = "${JWT_SECRET}"

        # 日志配置
        LOG_LEVEL = "${LOG_LEVEL}"
        LOG_FORMAT = "json"
      }

      resources {
        cpu    = 800
        memory = 768
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
