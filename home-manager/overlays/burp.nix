self:
{ xorg, stdenv, lib, fetchurl, jre, runtimeShell, makeDesktopItem, alsa-lib, nss
, nspr, cairo, cups, mesa, pango, glib, atk, at-spi2-atk, at-spi2-core, dbus
, expat, libdrm, libxkbcommon, ... }: {
  burppro = let
    version = "2024.1.1.5";
    product = "pro";
    executableName = "burpsuite";
    jar = fetchurl {
      name = "burpsuite.jar";
      url =
        "https://portswigger.net/Burp/Releases/Download?product=${product}&version=${version}&type=Jar";
      sha256 = "sha256-AGiawpgNJi6lQZGAoVmSmKrZkfRWzXPzEzaU2BICyiY=";
    };
    launcher = ''
      #!${runtimeShell}
              export LD_LIBRARY_PATH=${
                lib.makeLibraryPath [
                  xorg.libX11
                  xorg.libxcb
                  xorg.libXi
                  xorg.libXext
                  xorg.libXfixes
                  xorg.libXcomposite
                  xorg.libXdamage
                  xorg.libXrandr
                  alsa-lib
                  nss
                  nspr
                  cairo
                  cups
                  mesa
                  pango
                  glib
                  atk
                  at-spi2-atk
                  at-spi2-core
                  dbus
                  expat
                  libdrm
                  libxkbcommon
                ]
              }:$LD_LIBRARY_PATH
            exec ${jre}/bin/java -jar ${jar} "$@"
    '';
    desktopItem = makeDesktopItem {
      name = executableName;
      desktopName = "Burp Suite Professional";
      exec = executableName;
    };
  in stdenv.mkDerivation {
    pname = "burpsuite";
    inherit version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
        mkdir -p $out/bin
        echo "${launcher}" > $out/bin/${executableName}
      chmod +x $out/bin/${executableName}
      mkdir -p $out/share/applications
        ln -s ${desktopItem}/share/applications/* $out/share/applications
    '';

    preferLocalBuild = true;

    meta = {
      description =
        "An integrated platform for performing security testing of web applications";
      longDescription = ''
        Burp Suite is an integrated platform for performing security testing of web applications.
        Its various tools work seamlessly together to support the entire testing process, from
        initial mapping and analysis of an application's attack surface, through to finding and
        exploiting security vulnerabilities.
      '';
      homepage = "https://portswigger.net/burp/";
      downloadPage = "https://portswigger.net/burp/freedownload";
      license = [ lib.licenses.unfree ];
      platforms = jre.meta.platforms;
      hydraPlatforms = [ ];
    };
  };
}

