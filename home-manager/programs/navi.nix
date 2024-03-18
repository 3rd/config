{
  programs.navi = {
    enable = true;
    settings.cheats.paths = [ "~/brain/config/navi" ];
  };

  programs.fish.shellAliases = {
    n = "navi";
    navibest = "navi --best-match --query $argv";
  };

}
