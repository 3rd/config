{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxshmfence,
  libxscrnsaver,
  libxtst,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  buildId = "12dcfa973ef51585fd1b35df6839fc9d1d7fd6aa";
  runtimeLibs = [
    libdrm
    libGL
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libxkbcommon
    (lib.getLib systemd)
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "grok-bot";
  version = "0.44.0";

  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${buildId}/linux/x64/grok-bot_${finalAttrs.version}_amd64.deb";
    hash = "sha256-3e0YstPUSxwy1rn2NEbSsnvKaLPeeiqgKM55VulpQWQ=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxscrnsaver
    libxtst
    nspr
    nss
    pango
    stdenv.cc.cc.lib
  ]
  ++ runtimeLibs;

  runtimeDependencies = runtimeLibs;

  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb -x "$src" .

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/applications" "$out/share/grok-bot"
    cp -r "opt/Grok Bot/." "$out/share/grok-bot/"

    # the Nix store cannot carry the setuid bit; Chromium uses its user-namespace sandbox
    rm "$out/share/grok-bot/chrome-sandbox"

    cp -r usr/share/icons "$out/share/"
    install -Dm644 usr/share/applications/grok-bot.desktop "$out/share/applications/grok-bot.desktop"
    substituteInPlace "$out/share/applications/grok-bot.desktop" \
      --replace-fail 'Exec=grok-bot %U' "Exec=$out/bin/grok-bot %U"

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper "$out/share/grok-bot/grok-bot" "$out/bin/grok-bot" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set-default CHROME_DESKTOP grok-bot.desktop
  '';

  meta = {
    description = "Grok Bot desktop agent";
    homepage = "https://x.ai/news/introducing-grok-bot";
    license = lib.licenses.unfree;
    mainProgram = "grok-bot";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
