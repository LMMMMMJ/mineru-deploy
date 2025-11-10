# Package configuration for MinerU deployment
{ inputs, ... }:

{
  perSystem = { system, config, pkgs, ... }: {
    packages = {
      # Convenient deployment script
      mineru-deploy = pkgs.writeShellScriptBin "mineru-deploy" ''
        #!/usr/bin/env bash
        set -e
        
        # Color definitions
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m' # No Color
        
        # Find project directory (where flake.nix is located)
        PROJECT_DIR="$(pwd)"
        while [ ! -f "$PROJECT_DIR/flake.nix" ] && [ "$PROJECT_DIR" != "/" ]; do
          PROJECT_DIR="$(dirname "$PROJECT_DIR")"
        done
        
        if [ ! -f "$PROJECT_DIR/flake.nix" ]; then
          echo -e "''${RED}错误: 找不到 flake.nix，请在项目目录中运行此命令''${NC}"
          exit 1
        fi
        
        case "''${1:-help}" in
          build)
            echo -e "''${BLUE}🔨 Building MinerU Docker image...''${NC}"
            cd "$PROJECT_DIR"
            ${pkgs.wget}/bin/wget -q --show-progress -O Dockerfile https://gcore.jsdelivr.net/gh/opendatalab/MinerU@master/docker/global/Dockerfile
            ${pkgs.docker}/bin/docker build -t mineru-vllm:latest -f Dockerfile .
            rm -f Dockerfile
            echo -e "''${GREEN}✓ Image built successfully!''${NC}"
            ;;
            
          process)
            # 处理单个 PDF 文件
            if [ -z "''${2}" ]; then
              echo -e "''${RED}错误: 请指定输入 PDF 文件''${NC}"
              echo -e "用法: mineru-deploy process <input.pdf> [output_dir]"
              exit 1
            fi
            
            INPUT_FILE="$(realpath ''${2})"
            OUTPUT_DIR_REL="''${3:-./mineru_output}"
            mkdir -p "$OUTPUT_DIR_REL"
            OUTPUT_DIR="$(realpath $OUTPUT_DIR_REL)"
            
            if [ ! -f "$INPUT_FILE" ]; then
              echo -e "''${RED}错误: 文件不存在: $INPUT_FILE''${NC}"
              exit 1
            fi
            INPUT_DIR=$(dirname "$INPUT_FILE")
            INPUT_NAME=$(basename "$INPUT_FILE")
            
            echo -e "''${BLUE}📄 处理文件: $INPUT_NAME''${NC}"
            echo -e "''${BLUE}📁 输出目录: $OUTPUT_DIR''${NC}"
            
            # 使用 NixOS 正确的 GPU 参数
            ${pkgs.docker}/bin/docker run --rm \
              --device=nvidia.com/gpu=all \
              -v "$INPUT_DIR:/input:ro" \
              -v "$OUTPUT_DIR:/output" \
              mineru-vllm:latest \
              mineru -p "/input/$INPUT_NAME" -o /output
            
            # 修复文件权限
            echo -e "''${YELLOW}🔧 修复文件权限...''${NC}"
            sudo chown -R $(id -u):$(id -g) "$OUTPUT_DIR" 2>/dev/null || true
            
            echo -e "''${GREEN}✓ 处理完成!''${NC}"
            echo -e "''${GREEN}📂 输出位置: $OUTPUT_DIR''${NC}"
            ;;
            
          start)
            echo -e "''${BLUE}🚀 Starting MinerU services...''${NC}"
            cd "$PROJECT_DIR/mineru-service"
            
            # Check if any profile is specified
            if [ -z "''${2}" ]; then
              echo -e "''${YELLOW}Starting all services...''${NC}"
              ${pkgs.docker-compose}/bin/docker-compose --profile vllm-server --profile api --profile gradio up -d
            else
              echo -e "''${YELLOW}Starting ''${2} service...''${NC}"
              ${pkgs.docker-compose}/bin/docker-compose --profile "''${2}" up -d
            fi
            
            echo -e "''${GREEN}✓ Services started!''${NC}"
            ${pkgs.docker-compose}/bin/docker-compose ps
            ;;
            
          stop)
            echo -e "''${BLUE}🛑 Stopping MinerU services...''${NC}"
            cd "$PROJECT_DIR/mineru-service"
            ${pkgs.docker-compose}/bin/docker-compose down
            echo -e "''${GREEN}✓ Services stopped!''${NC}"
            ;;
            
          status)
            echo -e "''${BLUE}📊 MinerU services status:''${NC}"
            cd "$PROJECT_DIR/mineru-service"
            ${pkgs.docker-compose}/bin/docker-compose ps
            ;;
            
          logs)
            cd "$PROJECT_DIR/mineru-service"
            ${pkgs.docker-compose}/bin/docker-compose logs -f "''${2}"
            ;;
            
          restart)
            echo -e "''${BLUE}🔄 Restarting MinerU services...''${NC}"
            cd "$PROJECT_DIR/mineru-service"
            ${pkgs.docker-compose}/bin/docker-compose restart "''${2}"
            echo -e "''${GREEN}✓ Services restarted!''${NC}"
            ;;
            
          *)
            echo -e "''${BLUE}MinerU Deployment Tool''${NC}"
            echo ""
            echo "Usage: mineru-deploy <command> [options]"
            echo ""
            echo -e "''${GREEN}Commands:''${NC}"
            echo "  build                      - Build the MinerU Docker image"
            echo "  process <pdf> [output_dir] - Process a PDF file (GPU accelerated)"
            echo "  start [profile]            - Start services (vllm-server|api|gradio)"
            echo "  stop                       - Stop all services"
            echo "  status                     - Show service status"
            echo "  logs [service]             - Show service logs"
            echo "  restart [service]          - Restart services"
            echo ""
            echo -e "''${YELLOW}Examples:''${NC}"
            echo "  mineru-deploy build"
            echo "  mineru-deploy process document.pdf ./output"
            echo "  mineru-deploy start vllm-server"
            echo "  mineru-deploy logs"
            echo "  mineru-deploy stop"
            echo ""
            echo -e "''${BLUE}Note:''${NC} GPU access uses --device=nvidia.com/gpu=all (NixOS)"
            ;;
        esac
      '';
      
      default = config.packages.mineru-deploy;
    };
  };
}

