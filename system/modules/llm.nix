{
  config,
  pkgs,
  pkgs-master ? pkgs,
  pkgs-stable,
  options,
  ...
}:
let
  ollamaPackage = pkgs-master.ollama.override (
    {
      acceleration = "cuda";
    }
    // (
      if config.networking.hostName == "spaceship" then
        {
          cudaArches = [ "sm_120" ];
        }
      else
        { }
    )
  );
in
{

  hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;

  environment.systemPackages = [ ollamaPackage ];

  services.open-webui = {
    package = pkgs.open-webui;
    # package = pkgs-stable.open-webui;
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
