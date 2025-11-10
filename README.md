# MinerU NixOS Docker 部署

基于Docker的MinerU文档提取服务NixOS部署方案。

## 系统要求

- NixOS 系统
- NVIDIA GPU（Turing架构或更新，8GB+显存）
- NVIDIA驱动支持 CUDA 12.8+（使用 `nvidia-smi` 检查）
- 启用 Flakes 和 Nix Command

## 项目结构

```
mineru-deploy/
├── flake.nix                    # Flake 配置入口
├── nix/
│   ├── development.nix          # 开发环境配置
│   └── packages.nix             # 包和工具配置
├── mineru-service/
│   ├── module.nix              # NixOS 服务模块
│   └── compose.yaml            # Docker Compose 配置
└── README.md
```

## 快速开始

### 1. 启用 Nix Flakes

确保你的NixOS配置中启用了flakes：

```nix
{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

### 2. 进入开发环境

```bash
cd /path/to/mineru-deploy
nix develop
```

开发环境会自动显示：
- 系统信息
- Docker 状态
- GPU 状态
- 可用命令列表

### 3. 构建 Docker 镜像

方法一：使用便捷命令
```bash
mineru-deploy build
```

方法二：手动构建
```bash
wget https://gcore.jsdelivr.net/gh/opendatalab/MinerU@master/docker/global/Dockerfile
docker build -t mineru-vllm:latest -f Dockerfile .
```

### 4. 启动服务

使用便捷命令：

```bash
# 启动 vLLM 推理服务器
mineru-deploy start vllm-server

# 启动 Web API
mineru-deploy start api

# 启动 Gradio WebUI
mineru-deploy start gradio

# 启动所有服务
mineru-deploy start

# 查看服务状态
mineru-deploy status

# 查看日志
mineru-deploy logs

# 停止服务
mineru-deploy stop
```

或使用 docker-compose：

```bash
# 在 mineru-service 目录下
docker compose --profile vllm-server up -d
docker compose --profile api up -d
docker compose --profile gradio up -d
docker compose down
```

### 5. 配置 NixOS 系统服务（可选）

在你的 NixOS 配置中添加：

```nix
{
  imports = [ /path/to/mineru-deploy/mineru-service/module.nix ];

  services.mineru = {
    enable = true;
    dataDir = "/var/lib/mineru";
    
    # 启用你需要的服务
    vllmServer.enable = true;   # vLLM 推理服务器 (端口 30000)
    api.enable = false;          # Web API 服务 (端口 8000)
    gradio.enable = false;       # Gradio WebUI (端口 7860)
    
    gpuSupport = true;
  };
}
```

重建系统：

```bash
sudo nixos-rebuild switch
```

## 服务说明

### vLLM Server (端口 30000)
使用vLLM加速VLM模型推理，适合需要高性能推理的场景。

使用示例：
```bash
mineru -p <input_path> -o <output_path> -b vlm-http-client -u http://localhost:30000
```

### Web API (端口 8000)
提供RESTful API接口。

访问文档：`http://localhost:8000/docs`

### Gradio WebUI (端口 7860)
提供Web界面进行文档处理。

访问地址：`http://localhost:7860`

API文档：`http://localhost:7860/?view=api`

## 服务管理

### 开发模式（手动管理）

在 `nix develop` 环境中使用 `mineru-deploy` 命令：

```bash
mineru-deploy build                    # 构建 Docker 镜像
mineru-deploy start [profile]          # 启动服务
mineru-deploy stop                     # 停止服务
mineru-deploy status                   # 查看状态
mineru-deploy logs [service]           # 查看日志
mineru-deploy restart [service]        # 重启服务
```

### 系统服务模式（systemd 管理）

如果配置了 NixOS 系统服务：

```bash
# 查看服务状态
sudo systemctl status mineru

# 重启服务
sudo systemctl restart mineru

# 查看日志
sudo journalctl -u mineru -f

# 停止服务
sudo systemctl stop mineru
```

## 配置选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `services.mineru.enable` | bool | false | 启用MinerU服务 |
| `services.mineru.dataDir` | path | /var/lib/mineru | 数据目录 |
| `services.mineru.vllmServer.enable` | bool | true | 启用vLLM服务器 |
| `services.mineru.vllmServer.port` | port | 30000 | vLLM服务器端口 |
| `services.mineru.api.enable` | bool | false | 启用Web API |
| `services.mineru.api.port` | port | 8000 | API端口 |
| `services.mineru.gradio.enable` | bool | false | 启用Gradio WebUI |
| `services.mineru.gradio.port` | port | 7860 | Gradio端口 |
| `services.mineru.gpuSupport` | bool | true | 启用GPU支持 |

## 数据持久化

默认情况下，MinerU数据存储在 `/var/lib/mineru`，模型缓存存储在 `~/.cache/huggingface`。

可以通过修改 `compose.yaml` 中的卷挂载来调整：

```yaml
volumes:
  - /custom/data/path:/data
  - /custom/cache/path:/root/.cache/huggingface
```

## 故障排查

### GPU 未检测到
检查NVIDIA驱动和Docker GPU支持：
```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### 端口冲突
修改 `compose.yaml` 或 NixOS 配置中的端口设置。

### 显存不足
- 减少 `max-model-len` 参数
- 使用更小的模型
- 确保没有其他GPU进程占用显存

## 参考链接

- [MinerU 官方文档](https://opendatalab.github.io/MinerU/)
- [Docker 部署指南](https://opendatalab.github.io/MinerU/quick_start/docker_deployment/)

