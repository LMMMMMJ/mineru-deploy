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
        
        PROJECT_DIR="${inputs.self}"
        
        case "''${1:-help}" in
          build)
            echo -e "''${BLUE}🔨 Building MinerU Docker image...''${NC}"
            cd "$PROJECT_DIR"
            ${pkgs.wget}/bin/wget -q --show-progress -O Dockerfile https://gcore.jsdelivr.net/gh/opendatalab/MinerU@master/docker/global/Dockerfile
            ${pkgs.docker}/bin/docker build -t mineru-vllm:latest -f Dockerfile .
            rm -f Dockerfile
            echo -e "''${GREEN}✓ Image built successfully!''${NC}"
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
            echo "  build              - Build the MinerU Docker image"
            echo "  start [profile]    - Start services (vllm-server|api|gradio, or all if not specified)"
            echo "  stop               - Stop all services"
            echo "  status             - Show service status"
            echo "  logs [service]     - Show service logs (optionally for specific service)"
            echo "  restart [service]  - Restart services"
            echo ""
            echo -e "''${YELLOW}Examples:''${NC}"
            echo "  mineru-deploy build"
            echo "  mineru-deploy start vllm-server"
            echo "  mineru-deploy start"
            echo "  mineru-deploy logs"
            echo "  mineru-deploy stop"
            ;;
        esac
      '';
      
      default = config.packages.mineru-deploy;
    };
  };
}

