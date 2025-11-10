# Development environment configuration for MinerU deployment
{ inputs, ... }:

{
  perSystem = { system, config, pkgs, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    devShells.default = let 
      name = "MinerU-Deploy";
    in pkgs.mkShell {
      inherit name;
      
      packages = with pkgs; [
        # Docker tools
        docker
        docker-compose
        
        # System tools
        fish
        neofetch
        wget
        curl
        
        # Development utilities
        git
        jq
        htop
        
        # MinerU deploy command
        config.packages.mineru-deploy
      ];

      shellHook = ''
        # Set custom PS1 for visual distinction
        export PS1="$(echo -e '\uf489') {\[$(tput sgr0)\]\[\033[38;5;228m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]} (${name}) \\$ \[$(tput sgr0)\]"
        
        echo ""
        neofetch
        echo ""
        
        # Show Docker status
        echo -e "\033[1;36m🐳 Docker 状态:\033[0m"
        if systemctl is-active --quiet docker 2>/dev/null; then
          echo "  ✓ Docker 服务运行中"
          docker version --format '  Docker: {{.Server.Version}}' 2>/dev/null || echo "  Docker 已安装"
        else
          echo "  ✗ Docker 服务未运行 (使用 sudo systemctl start docker)"
        fi
        echo ""
        
        # Show GPU status
        echo -e "\033[1;33m🎮 GPU 状态:\033[0m"
        if command -v nvidia-smi &> /dev/null; then
          nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | while read line; do
            echo "  ✓ $line"
          done
        else
          echo "  ℹ NVIDIA 驱动未检测到"
        fi
        echo ""
        
        # Show available commands
        echo -e "\033[1;32m📦 MinerU 部署命令:\033[0m"
        echo "  🔨 构建镜像:"
        echo "     wget https://gcore.jsdelivr.net/gh/opendatalab/MinerU@master/docker/global/Dockerfile"
        echo "     docker build -t mineru-vllm:latest -f Dockerfile ."
        echo ""
        echo "  🚀 启动服务:"
        echo "     docker compose --profile vllm-server up -d  # vLLM 推理服务器"
        echo "     docker compose --profile api up -d          # Web API 服务"
        echo "     docker compose --profile gradio up -d       # Gradio WebUI"
        echo ""
        echo "  🛑 停止服务:"
        echo "     docker compose down"
        echo ""
        echo "  📊 查看日志:"
        echo "     docker compose logs -f"
        echo ""
        echo "  🔍 便捷命令: mineru-deploy {build|start|stop|logs}"
        echo ""
      '';
      
      # Environment variables
      SHELL = "${pkgs.fish}/bin/fish";
      NIXPKGS_ALLOW_UNFREE = "1";
      COMPOSE_PROJECT_NAME = "mineru";
    };
  };
}

