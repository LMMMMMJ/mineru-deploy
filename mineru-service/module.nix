{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mineru;
in
{
  options.services.mineru = {
    enable = mkEnableOption "MinerU document extraction service";

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/mineru";
      description = "Directory for MinerU data and models";
    };

    vllmServer = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable vLLM inference server";
      };

      port = mkOption {
        type = types.port;
        default = 30000;
        description = "Port for vLLM server";
      };
    };

    api = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Web API service";
      };

      port = mkOption {
        type = types.port;
        default = 8000;
        description = "Port for Web API";
      };
    };

    gradio = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Gradio WebUI service";
      };

      port = mkOption {
        type = types.port;
        default = 7860;
        description = "Port for Gradio WebUI";
      };
    };

    gpuSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Enable GPU support (requires NVIDIA GPU)";
    };
  };

  config = mkIf cfg.enable {
    # Ensure Docker is enabled
    virtualisation.docker = {
      enable = true;
      enableNvidia = cfg.gpuSupport;
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    # Docker Compose systemd service
    systemd.services.mineru = {
      description = "MinerU Document Extraction Service";
      after = [ "docker.service" "docker.socket" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        COMPOSE_PROJECT_NAME = "mineru";
        MINERU_DATA_DIR = cfg.dataDir;
        VLLM_PORT = toString cfg.vllmServer.port;
        API_PORT = toString cfg.api.port;
        GRADIO_PORT = toString cfg.gradio.port;
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/etc/mineru";
        
        ExecStartPre = [
          "${pkgs.coreutils}/bin/sleep 2"
        ];

        ExecStart = let
          profiles = []
            ++ optional cfg.vllmServer.enable "vllm-server"
            ++ optional cfg.api.enable "api"
            ++ optional cfg.gradio.enable "gradio";
          profileArgs = if profiles == [] then "" else "--profile " + concatStringsSep " --profile " profiles;
        in "${pkgs.docker-compose}/bin/docker-compose ${profileArgs} up -d";

        ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
        ExecReload = "${pkgs.docker-compose}/bin/docker-compose restart";

        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Copy compose.yaml to /etc/mineru
    environment.etc."mineru/compose.yaml" = {
      source = ../mineru-service/compose.yaml;
      mode = "0644";
    };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = []
      ++ optional cfg.vllmServer.enable cfg.vllmServer.port
      ++ optional cfg.api.enable cfg.api.port
      ++ optional cfg.gradio.enable cfg.gradio.port;
  };
}

