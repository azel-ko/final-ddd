job "databases" {
  datacenters = ["dc1"]
  type = "service"

  group "mysql" {
    count = 1

    network {
      port "mysql" {
        static = 3306
      }
    }

    service {
      name = "mysql"
      port = "mysql"

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "mysql" {
      driver = "docker"

      config {
        image = "docker.1ms.run/mysql:8.0"
        ports = ["mysql"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "mysql_data:/var/lib/mysql",
          "local/my.cnf:/etc/mysql/my.cnf"
        ]
      }

      env {
        MYSQL_ROOT_PASSWORD = "${DB_PASSWORD}"
        MYSQL_DATABASE = "${DB_NAME}"
        MYSQL_USER = "user"
        MYSQL_PASSWORD = "${DB_PASSWORD}"
      }

      template {
        data = <<EOF
# MySQL配置
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF
        destination = "local/my.cnf"
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    volume "mysql_data" {
      type      = "host"
      source    = "mysql_data"
      read_only = false
    }
  }

  group "postgres" {
    count = 0  # 默认不启动，可以通过变量控制

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
          "postgres_data:/var/lib/postgresql/data"
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

    volume "postgres_data" {
      type      = "host"
      source    = "postgres_data"
      read_only = false
    }
  }

  group "sqlite" {
    count = 0  # 默认不启动，可以通过变量控制

    task "sqlite" {
      driver = "docker"

      config {
        image = "docker.1ms.run/alpine:latest"
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "sqlite_data:/data",
          "${DB_PATH}:/data/external"
        ]
        command = "sh -c \"apk add --no-cache sqlite && chown -R 1000:1000 /data && tail -f /dev/null\""
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    volume "sqlite_data" {
      type      = "host"
      source    = "sqlite_data"
      read_only = false
    }
  }
}
