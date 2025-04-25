job "registry" {
  datacenters = ["dc1"]
  type = "service"

  # 固定在一个节点上运行
  constraint {
    attribute = "${node.unique.name}"
    value     = "n1"  # 替换为您想要运行 Registry 的节点名称
  }

  group "registry" {
    count = 1

    network {
      port "registry" {
        static = 5000
      }
    }

    service {
      name = "registry"
      port = "registry"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.registry.entrypoints=web",
        "traefik.http.routers.registry.rule=Host(`registry.${DOMAIN_NAME}`)"
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "registry"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # 不再需要预启动任务

    task "registry" {
      driver = "docker"

      config {
        image = "docker.1ms.run/registry:2"
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        ports = ["registry"]
        volumes = [
          "/opt/data/registry:/var/lib/registry"
        ]
      }

      # 不再需要创建持久化目录的模板

      env {
        # 使用文件系统存储
        REGISTRY_STORAGE = "filesystem"
        REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY = "/var/lib/registry"
        # 允许使用不安全的 HTTP 连接，简化开发环境配置
        # 生产环境应该配置 TLS
        REGISTRY_HTTP_ADDR = "0.0.0.0:5000"
        REGISTRY_HTTP_TLS_CERTIFICATE = ""
        REGISTRY_HTTP_TLS_KEY = ""
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # 不再使用 Nomad 卷定义，而是直接使用主机路径
  }
}
