job "postgres" {
  datacenters = ["dc1"]
  type = "service"

  group "postgres" {
    count = 1

    network {
      port "postgres" {
        static = 5432
      }
    }

    service {
      name = "postgres"
      port = "postgres"

      check {
        name     = "postgres-health"
        type     = "tcp"
        port     = "postgres"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:15-alpine"
        ports = ["postgres"]
        force_pull = false

        mount {
          type   = "bind"
          source = "/opt/data/postgres"
          target = "/var/lib/postgresql/data"
        }
      }

      env {
        POSTGRES_DB = "${DB_NAME}"
        POSTGRES_USER = "${DB_USER}"
        POSTGRES_PASSWORD = "${DB_PASSWORD}"
        PGDATA = "/var/lib/postgresql/data/pgdata"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      # 健康检查
      check {
        name     = "postgres-ready"
        type     = "script"
        command  = "/usr/local/bin/pg_isready"
        args     = ["-U", "${DB_USER}", "-d", "${DB_NAME}"]
        interval = "10s"
        timeout  = "3s"
      }
    }
  }
}
