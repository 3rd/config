{
  bash,
  claude-code,
  coreutils,
  electron,
  fetchurl,
  git,
  gnugrep,
  gnused,
  lib,
  makeDesktopItem,
  makeWrapper,
  nodejs,
  openssh,
  python3,
  stdenvNoCC,
  unzip,
  which,
  xdg-utils,
}:

let
  pname = "claude-desktop";
  version = "1.4758.0";
  appDir = "$out/share/${pname}";
  msix = fetchurl {
    url = "https://downloads.claude.ai/releases/win32/x64/${version}/Claude-fb266c24b61d94290860a3945b138d6d249425f6.msix";
    hash = "sha256-AuTuQldtwD3kOYPtlIoFNo2EJ1QRxRNU2MFjDCOYkho=";
  };
  electronForClaude = electron.overrideAttrs (_old: {
    version = "41.3.0";
    src = fetchurl {
      url = "https://github.com/electron/electron/releases/download/v41.3.0/electron-v41.3.0-linux-x64.zip";
      hash = "sha256-sg4DzxdPjlbiNRJ9eE3/gWHvS7nGu8PZODEwIl6x4qI=";
    };
  });
  runtimePath = lib.makeBinPath [
    bash
    claude-code
    coreutils
    git
    gnugrep
    gnused
    nodejs
    openssh
    python3
    which
    xdg-utils
  ];
  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Claude";
    comment = "Claude Desktop by Anthropic";
    exec = "${pname} %U";
    icon = pname;
    terminal = false;
    categories = [
      "Development"
      "Utility"
    ];
    mimeTypes = [ "x-scheme-handler/claude" ];
    startupWMClass = "Claude";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  nativeBuildInputs = [
    makeWrapper
    python3
    unzip
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        mkdir -p "${appDir}/resources" "$out/bin" "$out/share/applications"

        python - "${appDir}" "${version}" <<'PY'
    import json
    import pathlib
    import sys

    app_dir = pathlib.Path(sys.argv[1])
    version = sys.argv[2]
    package = {
        "name": "@ant/desktop",
        "version": version,
        "main": "main.js",
        "productName": "Claude",
        "private": True,
    }
    app_dir.joinpath("package.json").write_text(json.dumps(package, indent=2) + "\n")
    app_dir.joinpath("main.js").write_text(
        r"""const path = require('path');
    const Module = require('module');
    const { app } = require('electron');

    const resourcesDir = path.join(__dirname, 'resources');
    const asarPath = path.join(resourcesDir, 'app.asar');

    Object.defineProperty(process, 'resourcesPath', {
      value: resourcesDir,
      configurable: true,
    });

    app.getAppPath = () => asarPath;

    Object.defineProperty(app, 'isPackaged', {
      get: () => true,
      configurable: true,
    });

    app.setName('Claude');
    app.getVersion = () => '@VERSION@';

    if (process.env.ELECTRON_REMOTE_DEBUGGING_PORT) {
      app.commandLine.appendSwitch('remote-debugging-port', process.env.ELECTRON_REMOTE_DEBUGGING_PORT);
      app.commandLine.appendSwitch('remote-allow-origins', '*');
    }

    if (process.platform === 'linux') {
      if (!process.env.CLAUDE_CODE_LOCAL_BINARY) {
        try {
          const { execSync } = require('child_process');
          const claudePath = execSync('which claude', { encoding: 'utf8', timeout: 3000 }).trim();
          if (claudePath) process.env.CLAUDE_CODE_LOCAL_BINARY = claudePath;
        } catch {}
      }

      const compile = Module.prototype._compile;
      Module.prototype._compile = function (content, filename) {
        if (filename.includes('.vite/build/')) {
          const hostPlatformUnsupported =
            'if(process.platform==="win32")return A==="arm64"?"win32-arm64":"win32-x64";throw new Error(`Unsupported platform: ' +
            '$' +
            '{process.platform}-' +
            '$' +
            '{A}`)';

          const hostPlatformLinux =
            'if(process.platform==="win32")return A==="arm64"?"win32-arm64":"win32-x64";if(process.platform==="linux")return A==="arm64"?"darwin-arm64":"darwin-x64";throw new Error(`Unsupported platform: ' +
            '$' +
            '{process.platform}-' +
            '$' +
            '{A}`)';

          content = content.replace(
            'process.env.CLAUDE_CODE_LOCAL_BINARY}async initLocalBinary',
            'process.env.CLAUDE_CODE_LOCAL_BINARY&&(this.localBinaryInitPromise=this.initLocalBinary(process.env.CLAUDE_CODE_LOCAL_BINARY))}async initLocalBinary'
          );

          content = content.replace(
            'function O_r(){const e=process.platform;if(e!=="darwin"&&e!=="win32")return{status:"unsupported",reason:Qe().formatMessage({defaultMessage:"Cowork is not currently supported on {platform}",id:"gX/JCYf2fo"},{platform:wFA()}),unsupportedCode:"unsupported_platform"};',
            'function O_r(){if(process.platform==="linux")return{status:"supported"};const e=process.platform;if(e!=="darwin"&&e!=="win32")return{status:"unsupported",reason:Qe().formatMessage({defaultMessage:"Cowork is not currently supported on {platform}",id:"gX/JCYf2fo"},{platform:wFA()}),unsupportedCode:"unsupported_platform"};'
          );

          content = content.replace(
            'function Ose(){const e=process.platform,A=xse();return uo.files[e][A]??[]}',
            'function Ose(){const e=process.platform,A=xse();return uo.files[e]?.[A]??(e==="linux"?uo.files.darwin?.[A]:void 0)??[]}'
          );

          content = content.replace(hostPlatformUnsupported, hostPlatformLinux);

          content = content.replace(
            'Git\\\\mingw64\\\\bin`]:[]}',
            'Git\\\\mingw64\\\\bin`]:process.platform==="linux"?process.env.PATH.split(":").filter(Boolean):[]}'
          );

          content = content.replace(
            /(\w+)\.version=(\w+)\(\)\.appVersion;\1\.env=\{\};/g,
            '$1.version=$2().appVersion;$1.platform="darwin";$1.type="Darwin";$1.env={};'
          );

          content = content.replace(
            'const e=di("menuBarEnabled");if(Zue())return;',
            'const e=false;if(Zue())return;'
          );
        }
        return compile.call(this, content, filename);
      };

      app.on('browser-window-created', (_event, win) => {
        win.webContents.on('did-finish-load', () => {
          win.webContents.insertCSS('.nc-drag { display: none !important; }');
        });
      });
    }

    require(path.join(asarPath, '.vite', 'build', 'index.pre.js'));
    """.replace("@VERSION@", version))
    PY

        unzip -q "${msix}" 'app/resources/*' 'assets/icon.png' -d "$TMPDIR/msix"
        cp -r "$TMPDIR/msix/app/resources/." "${appDir}/resources/"
        install -Dm644 "$TMPDIR/msix/assets/icon.png" "${appDir}/resources/icon.png"
        install -Dm644 "$TMPDIR/msix/assets/icon.png" "$out/share/icons/hicolor/256x256/apps/${pname}.png"

        makeWrapper "${lib.getExe electronForClaude}" "$out/bin/${pname}" \
          --add-flags "${appDir}" \
          --add-flags "--no-sandbox" \
          --prefix PATH : "${runtimePath}" \
          --set-default CLAUDE_CODE_LOCAL_BINARY "${lib.getExe claude-code}"

        ln -s "${desktopItem}/share/applications/${pname}.desktop" "$out/share/applications/${pname}.desktop"

        runHook postInstall
  '';

  meta = {
    mainProgram = pname;
    description = "Claude Desktop on NixOS";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
