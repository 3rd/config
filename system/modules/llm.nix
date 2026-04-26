{
  inputs,
  lib,
  pkgs,
  pkgs-master ? pkgs,
  ...
}:

# 26B-A4B IQ3_S
# llm pull unsloth/gemma-4-26B-A4B-it-GGUF --quant IQ3_S --id gemma4-26b
# llm set gemma4-26b --ctx 8192 --gpu-layers 99 --batch 64 --ubatch 32
# llm start gemma4-26b
# llm test
# llm chat "write a short explanation of what you are"
# --ctx 16384
#
# E4B Q8_0
# llm pull ggml-org/gemma-4-E4B-it-GGUF --quant Q8_0 --id gemma4-e4b-q8
# llm set gemma4-e4b-q8 --ctx 65536 --gpu-layers 99 --batch 256 --ubatch 128
# llm start gemma4-e4b-q8
# llm test
# llm chat "write a short explanation of what you are"

let
  llmUser = "rabbit";
  llmRoot = "/storage/llm";
  llamaSwapPort = 11343;
  llamaSwapConfig = "${llmRoot}/registry/llama-swap.yaml";
  llamaCppPkgs = import inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [ inputs.llama-cpp.overlays.default ];
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "12.0" ];
      cudaForwardCompat = false;
    };
  };
  llamaCppPackage = llamaCppPkgs.llamaPackages.llama-cpp;
  llamaSwapPackage = pkgs-master.llama-swap or pkgs.llama-swap;
in
{
  hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;

  environment.systemPackages = [
    llamaCppPackage
    llamaSwapPackage
    pkgs.curl
    pkgs.fzf
    pkgs.jq
    pkgs.python3Packages.hf-xet
    pkgs.python3Packages.huggingface-hub
  ];

  systemd.tmpfiles.rules = [
    "d ${llmRoot} 0775 ${llmUser} users - -"
    "d ${llmRoot}/models 0775 ${llmUser} users - -"
    "d ${llmRoot}/cache 0775 ${llmUser} users - -"
    "d ${llmRoot}/cache/huggingface 0775 ${llmUser} users - -"
    "d ${llmRoot}/registry 0775 ${llmUser} users - -"
    "f ${llmRoot}/registry/models.json 0664 ${llmUser} users - {\"models\":{}}"
    "f ${llamaSwapConfig} 0664 ${llmUser} users - models: {}"
  ];

  systemd.services.llama-swap = {
    description = "Local OpenAI-compatible model swapper";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      llamaCppPackage
      llamaSwapPackage
    ];
    serviceConfig = {
      ExecStart = "${lib.getExe llamaSwapPackage} --listen 127.0.0.1:${toString llamaSwapPort} --config ${llamaSwapConfig} --watch-config";
      Restart = "on-failure";
      RestartSec = "5s";
      User = llmUser;
      WorkingDirectory = llmRoot;
      Environment = [
        "HF_HOME=${llmRoot}/cache/huggingface"
        "HF_XET_CACHE=${llmRoot}/cache/huggingface/xet"
      ];
      ReadWritePaths = [ llmRoot ];
    };
  };

  services.open-webui = {
    package = pkgs.open-webui;
    enable = true;
    port = 9999;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      ENABLE_OLLAMA_API = "False";
      ENABLE_OPENAI_API = "True";
      OPENAI_API_BASE_URL = "http://127.0.0.1:${toString llamaSwapPort}/v1";
      OPENAI_API_BASE_URLS = "http://127.0.0.1:${toString llamaSwapPort}/v1";
      OPENAI_API_KEY = "local";
      PORT = "9999";
      SCARF_NO_ANALYTICS = "True";
      WEBUI_URL = "http://localhost:9999";
    };
  };
}
