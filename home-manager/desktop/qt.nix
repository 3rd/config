{ config, pkgs, ... }:

let
  arcKvantumTheme = pkgs.runCommand "arc-kde-theme-opaque" { } ''
    cp -r ${pkgs.arc-kde-theme}/share/Kvantum/ArcDark $out
    chmod -R u+w $out
    substituteInPlace $out/ArcDark.kvconfig \
      --replace-fail 'translucent_windows=true' 'translucent_windows=false' \
      --replace-fail 'reduce_window_opacity=10' 'reduce_window_opacity=0' \
      --replace-fail 'blur_translucent=true' 'blur_translucent=false'
  '';
  qtctAppearance = {
    style = "kvantum";
    icon_theme = config.gtk.iconTheme.name;
    standard_dialogs = "xdgdesktopportal";
  };
  qtctFonts = {
    fixed = ''"Berkeley Mono,9"'';
    general = ''"DejaVu Sans,9"'';
  };
in
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    qt5ctSettings.Appearance = qtctAppearance;
    qt5ctSettings.Fonts = qtctFonts;
    qt6ctSettings.Appearance = qtctAppearance;
    qt6ctSettings.Fonts = qtctFonts;
  };

  home.packages = [
    pkgs.arc-kde-theme
  ];

  xdg.configFile."Kvantum/ArcDark".source = arcKvantumTheme;
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=ArcDark
  '';
}
