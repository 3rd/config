{
  config,
  lib,
  pkgs,
  ...
}:

let
  configureScript = "${config.xdg.configHome}/copyq/configure-clipboard-command.js";
  clipboardScript = "${config.xdg.configHome}/copyq/keep-clipboard.js";
  configureCommand = ''
    source(${builtins.toJSON configureScript});
    configureClipboardCommand(${builtins.toJSON clipboardScript});
  '';
  startCopyq = pkgs.writeShellApplication {
    name = "copyq-start";
    runtimeInputs = [ pkgs.copyq ];
    text = ''
      exec copyq --start-server eval ${lib.escapeShellArg configureCommand}
    '';
  };
in
{
  home.packages = [ startCopyq ];

  xdg.configFile = {
    "copyq/configure-clipboard-command.js".source = ./configure-clipboard-command.js;
    "copyq/keep-clipboard.js".source = ./keep-clipboard.js;
  };

  xsession.windowManager.i3.config.startup = [
    {
      always = true;
      command = "--no-startup-id ${lib.getExe startCopyq}";
    }
  ];
}
