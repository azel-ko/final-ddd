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
        volumes = [
          "rabbitmq_data:/var/lib/rabbitmq"
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

    volume "rabbitmq_data" {
      type      = "host"
      source    = "rabbitmq_data"
      read_only = false
    }
  }
}
