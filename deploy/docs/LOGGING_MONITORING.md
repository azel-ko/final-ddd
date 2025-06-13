# 日志监控方案

## 概述

本项目采用现代化的日志监控方案：**Grafana + Loki + Promtail**

### 架构组件

- **Loki**: 日志聚合系统，类似 Elasticsearch 但更轻量
- **Promtail**: 日志收集器，从各个节点收集日志
- **Grafana**: 可视化界面，查询和展示日志

## 部署方式

### 1. 快速部署
```bash
# 部署完整监控栈
./deploy/scripts/deploy-monitoring.sh

# 指定环境
./deploy/scripts/deploy-monitoring.sh --env prod
```

### 2. 分步部署
```bash
# 仅部署 Loki
./deploy/scripts/deploy-monitoring.sh --skip-grafana --skip-promtail

# 仅部署日志收集
./deploy/scripts/deploy-monitoring.sh --skip-grafana
```

## 配置说明

### 应用日志配置
在 `configs/config.yml` 中配置：
```yaml
log:
  level: info
  format: json          # 重要：使用 JSON 格式
  output: both          # stdout + file
  file_path: /opt/data/app/logs/app.log
```

### 环境变量
复制并修改 `deploy/configs/env/monitoring.env`：
```bash
cp deploy/configs/env/monitoring.env deploy/configs/env/prod.env
# 编辑 prod.env 设置生产环境参数
```

## 使用指南

### 1. 访问 Grafana
- URL: `https://grafana.your-domain.com`
- 默认用户名: `admin`
- 默认密码: `admin123` (请修改)

### 2. 查询日志
在 Grafana 的 Explore 页面：

**基本查询:**
```logql
{job="applications"}
```

**按级别过滤:**
```logql
{job="applications"} |= "ERROR"
```

**按服务过滤:**
```logql
{job="applications", service="final-ddd"}
```

**JSON 字段查询:**
```logql
{job="applications"} | json | level="error"
```

**时间范围查询:**
```logql
{job="applications"} | json | level="error" | __error__=""
```

### 3. 常用查询示例

**错误日志统计:**
```logql
sum(count_over_time({job="applications"} | json | level="error" [5m]))
```

**请求响应时间:**
```logql
{job="applications"} | json | __error__="" | unwrap duration | quantile_over_time(0.95, [5m])
```

**服务健康检查:**
```logql
{job="applications"} |= "health" | json
```

## 日志格式规范

### Go 应用日志格式
```json
{
  "time": "2024-01-15T10:30:00Z",
  "level": "info",
  "service": "final-ddd",
  "msg": "User login successful",
  "user_id": 123,
  "ip": "192.168.1.100",
  "duration": "150ms"
}
```

### 推荐的日志字段
- `time`: 时间戳 (RFC3339)
- `level`: 日志级别 (debug, info, warn, error)
- `service`: 服务名称
- `msg`: 日志消息
- `user_id`: 用户ID (如适用)
- `request_id`: 请求ID (用于链路追踪)
- `duration`: 操作耗时
- `error`: 错误信息

## 告警配置

### 1. 在 Grafana 中设置告警
- 创建告警规则
- 配置通知渠道 (邮件、Slack、钉钉等)

### 2. 常用告警规则
```logql
# 错误率过高
sum(rate({job="applications"} | json | level="error" [5m])) > 0.1

# 服务不可用
absent_over_time({job="applications"}[5m])

# 磁盘空间不足
{job="system"} |= "disk" |= "full"
```

## 性能优化

### 1. Loki 配置优化
- 调整保留期限 (默认14天)
- 配置压缩策略
- 设置查询限制

### 2. Promtail 优化
- 配置日志轮转
- 设置批量发送
- 过滤无用日志

### 3. 存储优化
```bash
# 清理旧日志
find /opt/data/loki -name "*.gz" -mtime +14 -delete

# 监控磁盘使用
df -h /opt/data
```

## 故障排查

### 1. 检查服务状态
```bash
nomad job status loki
nomad job status promtail
nomad job status grafana
```

### 2. 查看日志
```bash
nomad alloc logs <alloc-id> loki
nomad alloc logs <alloc-id> promtail
```

### 3. 常见问题

**Loki 无法启动:**
- 检查数据目录权限
- 确认端口未被占用

**Promtail 无法收集日志:**
- 检查日志文件路径
- 确认文件权限

**Grafana 无法连接 Loki:**
- 检查服务发现配置
- 确认网络连通性

## 扩展功能

### 1. 集成 Prometheus
- 添加应用指标监控
- 结合日志和指标分析

### 2. 链路追踪
- 集成 Jaeger
- 实现分布式追踪

### 3. 日志分析
- 配置日志解析规则
- 提取业务指标

## 最佳实践

1. **结构化日志**: 始终使用 JSON 格式
2. **合理分级**: 正确使用日志级别
3. **包含上下文**: 记录关键业务信息
4. **避免敏感信息**: 不记录密码、token等
5. **性能考虑**: 避免过度日志记录
6. **定期清理**: 设置合理的保留策略
