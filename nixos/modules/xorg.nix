{ pkgs, ... }:

# https://gist.github.com/kborling/76805ade81ac5bfdd712df294208c878
{
  environment.systemPackages = with pkgs; [ libinput ];

  services.xserver = {
    enable = true;
    displayManager = {
      lightdm.enable = true;
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
