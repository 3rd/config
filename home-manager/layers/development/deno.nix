{ pkgs, ... }:

{
  home.packages = with pkgs; [
    deno
  ];

  home = {
    sessionPath = [ "$HOME/.deno/bin" ];
    sessionVariables = {
      DENO_INSTALL_ROOT = "$HOME/.deno";
      DENO_NO_PROMPT = "1";
      DENO_NO_UPDATE_CHECK = "1";
    };
  };
}
