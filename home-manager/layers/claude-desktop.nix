{ pkgs, ... }:

{
  home.packages = with pkgs; [
    claude-code
    claudeDesktop
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications."x-scheme-handler/claude" = "claude-desktop.desktop";
  };
}
