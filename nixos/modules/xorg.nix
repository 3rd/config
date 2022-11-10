{ pkgs, ... }:

# https://gist.github.com/kborling/76805ade81ac5bfdd712df294208c878
{
  environment.systemPackages = with pkgs; [ libinput ];

  services.xserver = {
    enable = true;
    displayManager = {
      # lightdm.enable = true;
      sddm = {
        enable = true;
        # settings.Wayland.SessionDir = "${pkgs.plasma5Packages.plasma-workspace}/share/wayland-sessions";
      };
      defaultSession = "home-manager";
      session = [{
        name = "home-manager";
        manage = "desktop";
        start = ''
          ${pkgs.runtimeShell} $HOME/.hm-xsession
          waitPID=$!
        '';
      }];
      sessionCommands = ''
        systemctl --user import-environment QT_PLUGIN_PATH
      '';
    };
    desktopManager = {
      # plasma5.enable = true;
    };
    layout = "us";
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      touchpad = {
        # accelProfile = "flat";
        disableWhileTyping = false;
      };
    };
  };
}
