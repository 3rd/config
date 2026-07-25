{
  programs.navi = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    settings = {
      cheats.paths = [ "~/brain/config/navi" ];
      style.tag = {
        width_percentage = 10;
        min_width = 8;
      };
      finder.overrides = "--no-exact";
    };
  };

  programs.fish.shellAliases = {
    n = "navi";
    navibest = "navi --best-match --query $argv";
  };

}
