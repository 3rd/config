{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionals
    types
    ;

  cfg = config.tts;
in
{
  options.tts = {
    enable = mkEnableOption "tts tooling";

    piper = {
      enable = mkEnableOption "piper tts";

      voicePacks = mkOption {
        type = types.listOf types.package;
        default = [ pkgs.piperVoicePacks.librittsRMedium ];
        description = "Installed Piper voice packs.";
      };
    };

    kokoro = {
      enable = mkEnableOption "kokoro tts service";

      package = mkOption {
        type = types.package;
        default = pkgs.kokoroFastapiCpu;
        description = "Kokoro application package.";
      };

      modelPackage = mkOption {
        type = types.package;
        default = pkgs.kokoroModels.v1_0;
        description = "Kokoro model package.";
      };

      voicePack = mkOption {
        type = types.package;
        default = pkgs.kokoroVoicePacks.full;
        description = "Kokoro voice pack.";
      };

      defaultVoice = mkOption {
        type = types.str;
        default = "af_sky";
        description = "Default Kokoro voice.";
      };

      port = mkOption {
        type = types.port;
        default = 38480;
        description = "Kokoro HTTP port.";
      };

      extraEnv = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Additional environment variables for Kokoro.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      optionals cfg.piper.enable (
        [
          pkgs.piper-tts
          pkgs.piperLibrittsR
        ]
        ++ cfg.piper.voicePacks
      )
      ++ optionals cfg.kokoro.enable [
        cfg.kokoro.package
      ];

    systemd.user.services = mkIf cfg.kokoro.enable {
      kokoro = {
        Unit = {
          Description = "Kokoro Text-to-Speech Service";
          After = [ "network.target" ];
          Wants = [ "network.target" ];
        };

        Install.WantedBy = [ "default.target" ];

        Service =
          let
            extraEnvLines = lib.mapAttrsToList (name: value: "${name}=${value}") cfg.kokoro.extraEnv;
          in
          {
            Type = "notify";
            NotifyAccess = "all";
            Restart = "on-failure";
            RestartSec = 2;
            ExecStart = lib.getExe cfg.kokoro.package;
            WorkingDirectory = "%h";
            StateDirectory = "kokoro";
            CacheDirectory = "kokoro";
            RuntimeDirectory = "kokoro";
            RuntimeDirectoryPreserve = true;
            Environment = [
              "KOKORO_HOST=127.0.0.1"
              "KOKORO_PORT=${toString cfg.kokoro.port}"
              "KOKORO_STARTUP_TIMEOUT_SECONDS=120"
              "DEFAULT_VOICE=${cfg.kokoro.defaultVoice}"
              "ALLOW_LOCAL_VOICE_SAVING=false"
              "API_LOG_LEVEL=WARNING"
              "OUTPUT_DIR=%h/.local/state/kokoro/output"
              "TEMP_FILE_DIR=%h/.cache/kokoro/temp"
              "KOKORO_MODEL_DIR=${cfg.kokoro.modelPackage}/share/kokoro/models"
              "KOKORO_VOICES_DIR=${cfg.kokoro.voicePack}/share/kokoro/voices/v1_0"
            ]
            ++ extraEnvLines;
          };
      };
    };
  };
}
