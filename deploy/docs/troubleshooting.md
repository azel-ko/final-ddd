# 故障排除指南

本文档包含 Final DDD 应用部署过程中常见问题的解决方案。

## 常见问题

### 1. Nomad 作业部署失败

#### 问题：作业提交后一直处于 pending 状态

**可能原因：**
- 资源不足
- 约束条件不满足
- 镜像拉取失败

**解决方案：**

```bash
# 检查作业状态
nomad job status <job-name>

# 查看详细错误信息
nomad alloc status <alloc-id>
nomad alloc logs <alloc-id>

# 检查节点资源
nomad node status
nomad node status <node-id>
```

#### 问题：镜像拉取失败

**解决方案：**

```bash
# 检查 Docker 服务
sudo systemctl status docker

# 手动拉取镜像测试
docker pull <image-name>

# 检查镜像仓库连接
curl -v http://localhost:5000/v2/

# 重新构建并推送镜像
./deploy/scripts/build.sh --push --registry localhost:5000
```

### 2. 服务健康检查失败

#### 问题：服务启动但健康检查失败

**解决方案：**

```bash
# 检查服务日志
nomad alloc logs <alloc-id> <task-name>

# 检查端口是否正确监听
nomad alloc exec <alloc-id> <task-name> netstat -tlnp

# 手动测试健康检查端点
curl http://<service-ip>:<port>/api/health
```

### 3. Traefik 路由问题

#### 问题：无法通过域名访问应用

**解决方案：**

```bash
# 检查 Traefik 配置
curl http://localhost:8080/api/http/routers

# 检查服务注册
consul catalog services
consul catalog service <service-name>

# 检查 DNS 解析
nslookup <domain-name>
dig <domain-name>

# 检查 Traefik 日志
nomad alloc logs <traefik-alloc-id> traefik
```

### 4. 数据库连接问题

#### 问题：应用无法连接到 PostgreSQL

**解决方案：**

```bash
# 检查 PostgreSQL 服务状态
nomad job status postgres
consul catalog service postgres

# 测试数据库连接
nomad alloc exec <postgres-alloc-id> postgres psql -U postgres -d <db-name> -c "SELECT 1;"

# 检查网络连接
nomad alloc exec <app-alloc-id> app nc -zv <postgres-ip> 5432

# 检查环境变量
nomad alloc exec <app-alloc-id> app env | grep -i postgres
```

### 5. 存储问题

#### 问题：数据持久化失败

**解决方案：**

```bash
# 检查数据目录权限
ls -la /opt/data/
sudo chmod -R 755 /opt/data/

# 检查磁盘空间
df -h /opt/data/

# 检查挂载点
mount | grep /opt/data
```

## 调试命令

### Nomad 调试

```bash
# 查看所有作业
nomad job status

# 查看作业详情
nomad job status <job-name>

# 查看分配详情
nomad alloc status <alloc-id>

# 查看任务日志
nomad alloc logs <alloc-id> <task-name>

# 进入容器
nomad alloc exec <alloc-id> <task-name> /bin/sh

# 查看节点状态
nomad node status
nomad node status <node-id>
```

### Consul 调试

```bash
# 查看服务列表
consul catalog services

# 查看服务详情
consul catalog service <service-name>

# 查看健康检查
consul catalog service <service-name> -detailed

# 查看 KV 存储
consul kv get -recurse
```

### Docker 调试

```bash
# 查看容器状态
docker ps -a

# 查看容器日志
docker logs <container-id>

# 进入容器
docker exec -it <container-id> /bin/sh

# 查看镜像
docker images

# 清理资源
docker system prune -f
```

## 性能优化

### 1. 资源调优

```bash
# 调整作业资源配置
# 在 .nomad 文件中修改 resources 块
resources {
  cpu    = 1000  # 增加 CPU
  memory = 1024  # 增加内存
}
```

### 2. 网络优化

```bash
# 使用 host 网络模式（适用于单节点）
network {
  mode = "host"
}

# 或者使用 bridge 模式并映射端口
network {
  port "http" {
    static = 8080
  }
}
```

### 3. 存储优化

```bash
# 使用 SSD 存储
sudo mkdir -p /opt/data
sudo mount /dev/nvme0n1 /opt/data

# 调整文件系统参数
sudo tune2fs -o journal_data_writeback /dev/nvme0n1
```

## 监控和日志

### 1. 查看系统资源

```bash
# CPU 和内存使用
top
htop

# 磁盘使用
df -h
du -sh /opt/data/*

# 网络连接
netstat -tlnp
ss -tlnp
```

### 2. 日志收集

```bash
# 收集所有服务日志
mkdir -p /tmp/debug-logs
nomad job status | tail -n +2 | awk '{print $1}' | while read job; do
  nomad job status "$job" > "/tmp/debug-logs/${job}-status.txt"
done

# 打包日志
tar -czf debug-logs-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp debug-logs
```

## 联系支持

如果问题仍然无法解决，请提供以下信息：

1. 错误信息和日志
2. 系统环境信息
3. 部署配置文件
4. 重现步骤

可以使用以下命令收集环境信息：

```bash
# 系统信息
uname -a
cat /etc/os-release

# 服务版本
nomad version
consul version
docker version

# 服务状态
sudo systemctl status nomad consul docker
```
