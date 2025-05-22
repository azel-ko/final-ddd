job "redis" {
  datacenters = ["dc1"]
  type = "service"

  group "redis" {
    count = 1

    host_volume "redis-data" {
      path      = "/opt/data/redis"
      read_only = false
    }

    network {
      port "redis" {
        static = 6379
      }
    }

    service {
      name = "redis"
      port = "redis"

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "docker.1ms.run/redis:7.0"
        ports = ["redis"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "/opt/data/redis:/data"
        ]
        args = ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # 不再使用 Nomad 卷定义，而是直接使用主机路径
  }
}
