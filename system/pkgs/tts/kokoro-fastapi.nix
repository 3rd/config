{
  coreutils,
  curl,
  espeak-ng,
  fetchurl,
  fetchzip,
  lib,
  modelPackage ? null,
  python3,
  stdenv,
  stdenvNoCC,
  systemd,
  voicePack ? null,
  writeShellApplication,
  zlib,
  cudaSupport ? false,
}:

let
  version = "0.2.4";
  pythonForKokoro = python3.override {
    packageOverrides =
      final: prev:
      let
        torchPackage = if cudaSupport then prev.torchWithCuda else prev.torchWithoutCuda;
        curatedTransformersPackage = prev."curated-transformers".override {
          torch = torchPackage;
        };
        spacyCuratedTransformersPackage = prev."spacy-curated-transformers".override {
          torch = torchPackage;
          "curated-transformers" = curatedTransformersPackage;
        };
        misakiPackage = prev.misaki.override {
          torch = torchPackage;
          "spacy-curated-transformers" = spacyCuratedTransformersPackage;
        };
      in
      {
        "curated-transformers" = curatedTransformersPackage;
        "spacy-curated-transformers" = spacyCuratedTransformersPackage;
        misaki = misakiPackage;
        kokoro = prev.kokoro.override {
          torch = torchPackage;
          misaki = misakiPackage;
        };
      };
  };
  pythonPackages = pythonForKokoro.pkgs;

  src = fetchzip {
    url = "https://github.com/remsky/Kokoro-FastAPI/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-fh1pSmrJuGwl9HuvKLBUf3bZZWwvf8WOA3iopAVDKlk=";
  };

  enCoreWebSm = pythonPackages.buildPythonPackage {
    pname = "en-core-web-sm";
    version = "3.8.0";
    format = "wheel";
    src = fetchurl {
      name = "en_core_web_sm-3.8.0-py3-none-any.whl";
      url = "https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl";
      hash = "sha256-GTJCnbcn1L/z3u1rNM/AXfF3lPSlLusmz4ko98Gg+4U=";
    };
    propagatedBuildInputs = [ pythonPackages.spacy ];
  };

  pythonEnv = pythonForKokoro.withPackages (
    ps: with ps; [
      aiofiles
      av
      click
      fastapi
      inflect
      kokoro
      loguru
      matplotlib
      misaki
      munch
      mutagen
      numpy
      openai
      phonemizer
      psutil
      regex
      spacy
      enCoreWebSm
      pydantic
      pydantic-settings
      pydub
      python-dotenv
      requests
      scipy
      soundfile
      sqlalchemy
      tiktoken
      tqdm
      uvicorn
    ]
  );

  assets = stdenvNoCC.mkDerivation {
    pname = "kokoro-fastapi-app";
    inherit version src;
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out/share/kokoro"
      cp -r api "$out/share/kokoro/api"
      cp -r web "$out/share/kokoro/web"
    '';
  };

  runtimeLibraryPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    zlib
  ];

  defaultModelDir = if modelPackage == null then "" else "${modelPackage}/share/kokoro/models";

  defaultVoicesDir = if voicePack == null then "" else "${voicePack}/share/kokoro/voices/v1_0";
in
writeShellApplication {
  name = if cudaSupport then "kokoro-fastapi-cuda" else "kokoro-fastapi-cpu";
  runtimeInputs = [
    coreutils
    curl
    systemd
  ];
  meta.mainProgram = if cudaSupport then "kokoro-fastapi-cuda" else "kokoro-fastapi-cpu";
  text = ''
    set -euo pipefail

    host="''${KOKORO_HOST:-127.0.0.1}"
    port="''${KOKORO_PORT:-38480}"
    health_url="http://''${host}:''${port}/health"
    startup_timeout="''${KOKORO_STARTUP_TIMEOUT_SECONDS:-120}"
    model_dir="''${KOKORO_MODEL_DIR:-${defaultModelDir}}"
    voices_dir="''${KOKORO_VOICES_DIR:-${defaultVoicesDir}}"

    if [ -z "$model_dir" ]; then
      echo "KOKORO_MODEL_DIR must be set" >&2
      exit 1
    fi

    if [ -z "$voices_dir" ]; then
      echo "KOKORO_VOICES_DIR must be set" >&2
      exit 1
    fi

    export USE_GPU="''${USE_GPU:-${if cudaSupport then "true" else "false"}}"
    export USE_ONNX="''${USE_ONNX:-false}"
    export DEVICE_TYPE="''${DEVICE_TYPE:-${if cudaSupport then "cuda" else "cpu"}}"
    export DEFAULT_VOICE="''${DEFAULT_VOICE:-af_sky}"
    export ALLOW_LOCAL_VOICE_SAVING="''${ALLOW_LOCAL_VOICE_SAVING:-false}"
    export OUTPUT_DIR="''${OUTPUT_DIR:-$HOME/.local/state/kokoro/output}"
    export TEMP_FILE_DIR="''${TEMP_FILE_DIR:-$HOME/.cache/kokoro/temp}"
    export API_LOG_LEVEL="''${API_LOG_LEVEL:-WARNING}"
    export PYTHONPATH='${assets}/share/kokoro:${assets}/share/kokoro/api'
    export MODEL_DIR="$model_dir"
    export VOICES_DIR="$voices_dir"
    export WEB_PLAYER_PATH="''${WEB_PLAYER_PATH:-${assets}/share/kokoro/web}"
    export ESPEAK_DATA_PATH='${espeak-ng}/share/espeak-ng-data'
    export LD_LIBRARY_PATH="${runtimeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    mkdir -p "$OUTPUT_DIR" "$TEMP_FILE_DIR"

    ${pythonEnv}/bin/python -m uvicorn api.src.main:app --host "$host" --port "$port" &
    server_pid=$!

    if [ -n "''${NOTIFY_SOCKET:-}" ]; then
      ready=0
      for _ in $(seq 1 "$startup_timeout"); do
        if ! kill -0 "$server_pid" 2>/dev/null; then
          wait "$server_pid"
          exit $?
        fi

        if ${curl}/bin/curl -sf "$health_url" >/dev/null 2>&1; then
          ${systemd}/bin/systemd-notify --ready --status="kokoro ready on $host:$port"
          ready=1
          break
        fi

        sleep 1
      done

      if [ "$ready" -ne 1 ]; then
        echo "kokoro failed to become healthy at $health_url" >&2
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" || true
        exit 1
      fi
    fi

    wait "$server_pid"
  '';
}
