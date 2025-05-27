# 环境搭建指南

本文档介绍如何搭建 Final DDD 应用的部署环境。

## 系统要求

- Linux 系统 (Ubuntu 20.04+ 推荐)
- Docker 20.10+
- 至少 4GB 内存
- 至少 20GB 磁盘空间

## 安装依赖

### 1. 安装 Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 重新登录或执行
newgrp docker
```

### 2. 安装 Nomad

```bash
# 下载并安装 Nomad
NOMAD_VERSION="1.6.1"
curl -O https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
sudo mv nomad /usr/local/bin/
sudo chmod +x /usr/local/bin/nomad

# 验证安装
nomad version
```

### 3. 安装 Consul

```bash
# 下载并安装 Consul
CONSUL_VERSION="1.16.1"
curl -O https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo mv consul /usr/local/bin/
sudo chmod +x /usr/local/bin/consul

# 验证安装
consul version
```

## 配置服务

### 1. 配置 Consul

创建 Consul 配置文件：

```bash
sudo mkdir -p /etc/consul.d
sudo tee /etc/consul.d/consul.hcl > /dev/null <<EOF
datacenter = "dc1"
data_dir = "/opt/consul"
log_level = "INFO"
server = true
bootstrap_expect = 1
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
retry_join = ["127.0.0.1"]
ui_config {
  enabled = true
}
connect {
  enabled = true
}
EOF
```

创建 systemd 服务：

```bash
sudo tee /etc/systemd/system/consul.service > /dev/null <<EOF
[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 2. 配置 Nomad

创建 Nomad 配置文件：

```bash
sudo mkdir -p /etc/nomad.d
sudo tee /etc/nomad.d/nomad.hcl > /dev/null <<EOF
datacenter = "dc1"
data_dir = "/opt/nomad"
log_level = "INFO"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true
  servers = ["127.0.0.1:4647"]
  
  host_volume "opt-data" {
    path = "/opt/data"
    read_only = false
  }
}

consul {
  address = "127.0.0.1:8500"
}

ui {
  enabled = true
}
EOF
```

创建 systemd 服务：

```bash
sudo tee /etc/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/nomad.d/nomad.hcl

[Service]
Type=notify
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/nomad.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 3. 创建用户和目录

```bash
# 创建用户
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo useradd --system --home /etc/nomad.d --shell /bin/false nomad

# 创建数据目录
sudo mkdir -p /opt/consul /opt/nomad /opt/data
sudo chown -R consul:consul /opt/consul /etc/consul.d
sudo chown -R nomad:nomad /opt/nomad /etc/nomad.d
sudo chmod -R 755 /opt/data
```

## 启动服务

```bash
# 启动并启用服务
sudo systemctl daemon-reload
sudo systemctl enable consul nomad
sudo systemctl start consul
sleep 5
sudo systemctl start nomad

# 检查服务状态
sudo systemctl status consul
sudo systemctl status nomad
```

## 验证安装

```bash
# 检查 Consul
consul members
curl http://localhost:8500/v1/status/leader

# 检查 Nomad
nomad server members
nomad node status
curl http://localhost:4646/v1/status/leader
```

## 访问 Web UI

- Consul UI: http://localhost:8500
- Nomad UI: http://localhost:4646

## 防火墙配置

如果启用了防火墙，需要开放以下端口：

```bash
# Consul
sudo ufw allow 8300/tcp  # Server RPC
sudo ufw allow 8301/tcp  # Serf LAN
sudo ufw allow 8301/udp  # Serf LAN
sudo ufw allow 8500/tcp  # HTTP API
sudo ufw allow 8600/tcp  # DNS
sudo ufw allow 8600/udp  # DNS

# Nomad
sudo ufw allow 4646/tcp  # HTTP API
sudo ufw allow 4647/tcp  # RPC
sudo ufw allow 4648/tcp  # Serf WAN

# 应用端口
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 8080/tcp  # Traefik Dashboard
```

## 下一步

环境搭建完成后，可以使用部署脚本部署应用：

```bash
cd /path/to/final-ddd
./deploy/scripts/deploy.sh --env dev
```
