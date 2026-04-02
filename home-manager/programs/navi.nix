{
  programs.navi = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    settings.cheats.paths = [ "~/brain/config/navi" ];
  };

  programs.fish.shellAliases = {
    n = "navi";
    navibest = "navi --best-match --query $argv";
  };

}
