{ pkgs, ... }:

{
  home.packages = with pkgs; [
    claude-code
    claudeDesktop
  ];

  xdg.configFile."Claude/claude_desktop_linux_config.json".text = builtins.toJSON {
    preferences.coworkBwrapMounts.additionalROBinds = [
      "/nix/store"
      {
        src = "/run/current-system/sw/bin";
        dst = "/usr/bin";
      }
    ];
  };
}
