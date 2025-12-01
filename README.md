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

## 性能优化配置

### 资源限制

API 和 Gradio 服务已配置资源限制（在 `compose.yaml` 中）：

- **CPU**: 最多 4 核（保留 2 核）
- **内存**: 最多 32GB（保留 8GB）
- **共享内存**: 16GB

### 环境变量优化

在 `compose.yaml` 中已配置以下优化环境变量：

```yaml
environment:
  - OMP_NUM_THREADS=4      # 限制 OpenMP 线程数
  - TORCH_NUM_THREADS=4    # 限制 PyTorch 线程数
  - MINERU_BATCH_SIZE=2    # MinerU 内部批大小
```

### GPU 和设备配置

MinerU 会自动检测并使用 GPU。可以通过环境变量控制：

```bash
# 指定使用的 GPU 设备
CUDA_VISIBLE_DEVICES=0 mineru-api --port 8000

# 多卡并行（如果有多张显卡）
CUDA_VISIBLE_DEVICES=0,1 mineru-api --port 8000
```

### 性能监控

**监控 GPU 使用**：
```bash
# 实时监控
watch -n 1 nvidia-smi

# 查看容器 GPU 使用
docker exec mineru-api nvidia-smi

# 查看容器资源使用
docker stats mineru-api
```

### 处理大型 PDF 建议

1. **分批处理**：将超大 PDF（100+页）拆分为多个小文件
2. **调整资源限制**：根据实际情况修改 `compose.yaml` 中的 CPU/内存限制
3. **监控显存**：处理时使用 `nvidia-smi` 监控，确保不超过限制
4. **关闭不需要的服务**：只启动需要的服务以节省资源

### 预期性能

| PDF 大小 | 预计处理时间 |
|---------|------------|
| 小型 (<10页) | 3-5秒 |
| 中型 (10-50页) | 15-30秒 |
| 大型 (50-100页) | 1-3分钟 |
| 超大 (100+页) | 3-10分钟 |

*实际性能取决于 PDF 复杂度（图片、表格、公式数量）*

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
docker run --rm --device=nvidia.com/gpu=all mineru-vllm:latest nvidia-smi
```

**注意**：在 NixOS 上必须使用 `--device=nvidia.com/gpu=all` 而不是 `--gpus all`

### 端口冲突
修改 `compose.yaml` 或 NixOS 配置中的端口设置。

### 模型文件缺失
如果遇到 "No such file or directory" 错误（如 MFD 模型）：

```bash
# 在运行的容器中重新下载模型
docker exec -it mineru-api mineru-models-download -s huggingface -m all

# 或重启服务
mineru-deploy stop
mineru-deploy start api
```

### 显存不足 (OOM)
1. **监控显存**：使用 `nvidia-smi` 查看实时使用情况
2. **减少并发**：一次只处理一个文件
3. **分批处理**：将大型 PDF 拆分为多个小文件
4. **调整资源限制**：在 `compose.yaml` 中降低 `shm_size`

### 处理速度慢
1. **检查 GPU 利用率**：`nvidia-smi` 应该显示 >50% 使用率
2. **检查资源限制**：确保没有 CPU/内存瓶颈
3. **使用命令行模式**：`mineru-deploy process` 可能比 API 更快
4. **关闭不需要的服务**：只启动必需的服务

### 大型 PDF 超时
1. **增加超时时间**：修改 API 调用的超时设置
2. **分批处理**：将大型 PDF（100+页）拆分为多个文件
3. **使用命令行**：直接使用 `mineru` 命令而不是通过 API

## 参考链接

- [MinerU 官方文档](https://opendatalab.github.io/MinerU/)
- [Docker 部署指南](https://opendatalab.github.io/MinerU/quick_start/docker_deployment/)

