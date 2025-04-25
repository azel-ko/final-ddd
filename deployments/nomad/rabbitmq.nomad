job "rabbitmq" {
  datacenters = ["dc1"]
  type = "service"

  group "rabbitmq" {
    count = 1

    network {
      port "amqp" {
        static = 5672
      }
      port "management" {
        static = 15672
      }
    }

    service {
      name = "rabbitmq"
      port = "amqp"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.rabbitmq.rule=Host(`rabbitmq.service.consul`)",
        "traefik.http.services.rabbitmq.loadbalancer.server.port=15672"
      ]

      check {
        type     = "tcp"
        port     = "amqp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "rabbitmq" {
      driver = "docker"

      config {
        image = "docker.1ms.run/rabbitmq:4-management"
        ports = ["amqp", "management"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "/opt/data/rabbitmq:/var/lib/rabbitmq"
        ]
      }

      env {
        RABBITMQ_DEFAULT_USER = "${RABBITMQ_USER}"
        RABBITMQ_DEFAULT_PASS = "${RABBITMQ_PASSWORD}"
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }

    # 不再使用 Nomad 卷定义，而是直接使用主机路径
  }
}
