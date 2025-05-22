job "databases" {
  datacenters = ["dc1"]
  type = "service"

  group "postgres" {
    count = 1  # 默认启动

    host_volume "pgdata" {
      path      = "/opt/data/postgres"
      read_only = false
    }

    network {
      port "postgres" {
        static = 5432
      }
    }

    service {
      name = "postgres"
      port = "postgres"

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "docker.1ms.run/postgres:14"
        ports = ["postgres"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "/opt/data/postgres:/var/lib/postgresql/data"
        ]
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
    }

    # 不再使用 Nomad 卷定义，而是直接使用主机路径
  }

  # 不再部署 SQLite
}
