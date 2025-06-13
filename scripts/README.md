# Scripts 目录

本目录包含开发环境使用的构建脚本。

## 文件说明

### build.sh
用于开发环境的快速构建脚本，生成单体二进制文件。

**功能:**
- 构建前端应用 (React + Vite)
- 将前端资源嵌入到 Go 应用中
- 编译 Go 后端代码
- 生成包含版本信息的二进制文件

**使用方法:**
```bash
./scripts/build.sh
```

**输出:**
- `final-ddd` - 包含前后端的单体二进制文件

## 与 deploy/scripts 的区别

- `./scripts/` - 开发环境使用，生成本地二进制文件
- `./deploy/scripts/` - 生产环境使用，构建 Docker 镜像和 Nomad 部署

## 使用场景

1. **本地开发测试**
   ```bash
   ./scripts/build.sh
   ./final-ddd
   ```

2. **生产环境部署**
   ```bash
   ./deploy/scripts/build.sh --tag v1.0.0
   ./deploy/scripts/deploy.sh --env prod
   ```

## 注意事项

- 确保已安装 pnpm (前端包管理器)
- 确保已安装 Go 1.21+ 
- 构建前会自动安装前端依赖
- 生成的二进制文件包含完整的前后端功能
