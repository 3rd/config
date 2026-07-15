{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.osd;
  ddcMonitorType = lib.types.submodule {
    options = {
      label = lib.mkOption {
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9._ -]*";
        description = "Human-readable monitor identity used in control errors.";
      };
      edid = lib.mkOption {
        type = lib.types.strMatching "[0-9A-Fa-f]{256}";
        description = "Stable 128-byte base EDID used as the ddcutil selector.";
      };
      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this monitor supplies the starting brightness percentage.";
      };
    };
  };
  ddcMonitorLines = lib.concatMapStringsSep "\n" (
    monitor: "${monitor.label}|${lib.toLower monitor.edid}|${if monitor.primary then "1" else "0"}"
  ) cfg.displayBrightness.ddcMonitors;
  monitorLabels = map (monitor: monitor.label) cfg.displayBrightness.ddcMonitors;
  monitorEdids = map (monitor: lib.toLower monitor.edid) cfg.displayBrightness.ddcMonitors;
  primaryMonitorCount = builtins.length (
    builtins.filter (monitor: monitor.primary) cfg.displayBrightness.ddcMonitors
  );
  desktopOsd = pkgs.writeShellApplication {
    name = "desktop-osd";
    runtimeInputs = [
      pkgs.brightnessctl
      pkgs.coreutils
      pkgs.gawk
      pkgs.libnotify
      pkgs.pulseaudio
      pkgs.util-linux
    ]
    ++ lib.optionals (cfg.displayBrightness.backend == "ddc") [
      pkgs.ddcutil
      pkgs.xrandr
    ];
    text = ''
      export DESKTOP_OSD_BRIGHTNESS_BACKEND=${lib.escapeShellArg cfg.displayBrightness.backend}
      export DESKTOP_OSD_DISPLAY_STEP=${lib.escapeShellArg (toString cfg.displayBrightness.step)}
      export DESKTOP_OSD_KEYBOARD_STEP=25
      export DESKTOP_OSD_VOLUME_STEP=5
      export DESKTOP_OSD_DDC_MONITORS=${lib.escapeShellArg ddcMonitorLines}

      ${builtins.readFile ./desktop-osd.sh}
    '';
  };
in
{
  options.desktop.osd = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "Packaged desktop hardware control and OSD command.";
    };

    displayBrightness = {
      backend = lib.mkOption {
        type = lib.types.enum [
          "disabled"
          "single-backlight"
          "ddc"
        ];
        default = "disabled";
        description = "Explicit backend used for display brightness control.";
      };
      step = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 5;
        description = "Display brightness change in percentage points.";
      };
      ddcMonitors = lib.mkOption {
        type = lib.types.listOf ddcMonitorType;
        default = [ ];
        description = "Configured DDC/CI monitors selected by stable base EDID.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion =
          cfg.displayBrightness.backend != "ddc"
          || (
            cfg.displayBrightness.ddcMonitors != [ ]
            && primaryMonitorCount == 1
            && builtins.length monitorLabels == builtins.length (lib.unique monitorLabels)
            && builtins.length monitorEdids == builtins.length (lib.unique monitorEdids)
          );
        message = "desktop.osd DDC brightness requires monitors with unique labels and EDIDs and exactly one primary";
      }
    ];

    desktop.osd.package = desktopOsd;
    home.packages = [ desktopOsd ];
  };
}
