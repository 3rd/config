{ pkgs }:

let
  inherit (pkgs) fetchurl stdenvNoCC;

  mkPiperVoicePack =
    {
      name,
      modelName,
      modelUrl,
      modelHash,
      configName,
      configUrl,
      configHash,
      relativePath,
    }:
    let
      model = fetchurl {
        name = modelName;
        url = modelUrl;
        hash = modelHash;
      };

      config = fetchurl {
        name = configName;
        url = configUrl;
        hash = configHash;
      };
    in
    stdenvNoCC.mkDerivation {
      pname = name;
      version = "1.0.0";
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out/share/piper-voices/${relativePath}"
        ln -s ${model} "$out/share/piper-voices/${relativePath}/${modelName}"
        ln -s ${config} "$out/share/piper-voices/${relativePath}/${configName}"
      '';
    };

  piperLibrittsRMedium = mkPiperVoicePack {
    name = "piper-voice-en_US-libritts_r-medium";
    modelName = "en_US-libritts_r-medium.onnx";
    modelUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/libritts_r/medium/en_US-libritts_r-medium.onnx?download=true";
    modelHash = "sha256-ELuF4HHWFvz0Bx82nxeZ0EkUkqs8XVUuwZ+1SPrBMZU=";
    configName = "en_US-libritts_r-medium.onnx.json";
    configUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/libritts_r/medium/en_US-libritts_r-medium.onnx.json?download=true";
    configHash = "sha256-tHHcYNLYM16BnDk9GW1vv3koF/QAUSV7Jph4UFvJr7M=";
    relativePath = "en_US/libritts_r/medium";
  };

  kokoroSrc = pkgs.fetchzip {
    url = "https://github.com/remsky/Kokoro-FastAPI/archive/refs/tags/v0.2.4.tar.gz";
    hash = "sha256-fh1pSmrJuGwl9HuvKLBUf3bZZWwvf8WOA3iopAVDKlk=";
  };

  kokoroModelV1 = stdenvNoCC.mkDerivation {
    pname = "kokoro-models-v1_0";
    version = "0.1.4";
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/share/kokoro/models/v1_0"
      ln -s ${
        fetchurl {
          name = "kokoro-v1_0.pth";
          url = "https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/kokoro-v1_0.pth";
          hash = "sha256-SW26EY0aWPXz2y78iNvcIW4Eg/yJ/m5H7h8sU/GK0eQ=";
        }
      } "$out/share/kokoro/models/v1_0/kokoro-v1_0.pth"
      ln -s ${
        fetchurl {
          name = "kokoro-config.json";
          url = "https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/config.json";
          hash = "sha256-WrsB4kA7ByvwPQT94WBEPiCdeg2tSaQjvhUZa5tDwX8=";
        }
      } "$out/share/kokoro/models/v1_0/config.json"
    '';
  };

  kokoroVoicePackFull = stdenvNoCC.mkDerivation {
    pname = "kokoro-voice-pack-full";
    version = "0.2.4";
    src = kokoroSrc;
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out/share/kokoro/voices"
      cp -r api/src/voices/v1_0 "$out/share/kokoro/voices/v1_0"
    '';
  };
in
{
  inherit mkPiperVoicePack;

  piperVoicePacks = {
    librittsRMedium = piperLibrittsRMedium;
  };

  piperLibrittsR = pkgs.callPackage ./piper-libritts-r.nix {
    voicePackage = piperLibrittsRMedium;
    modelPath = "en_US/libritts_r/medium/en_US-libritts_r-medium.onnx";
  };

  kokoroModels = {
    v1_0 = kokoroModelV1;
  };

  kokoroVoicePacks = {
    full = kokoroVoicePackFull;
  };

  kokoroFastapiCpu = pkgs.callPackage ./kokoro-fastapi.nix {
    modelPackage = kokoroModelV1;
    voicePack = kokoroVoicePackFull;
  };

  kokoroFastapiCuda = pkgs.callPackage ./kokoro-fastapi.nix {
    cudaSupport = true;
    modelPackage = kokoroModelV1;
    voicePack = kokoroVoicePackFull;
  };
}
