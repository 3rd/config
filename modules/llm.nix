{ config, pkgs, pkgs-stable, options, ... }: {

  environment.systemPackages = with pkgs;
    [
      #
      oterm
      # (pkgs.ollama.override { acceleration = "cuda"; })
    ];

  services.open-webui = {
    enable = true;
    port = 9999;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_URL = "http://localhost:9999";
      PORT = "9999";
    };
  };
}
