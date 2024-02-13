{ pkgs, lib, ... }:

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
        ${
          lib.getBin pkgs.dbus
        }/bin/dbus-update-activation-environment --systemd --all
      '';
    };
    xkb.layout = "us";
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
