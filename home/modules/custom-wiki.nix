{ config, pkgs, ... }:

let
  wiki_root = "$HOME/brain/wiki";
  task_root = "$HOME/brain/wiki";
in
{
  home.sessionVariables = {
    TASK_ROOT = task_root;
    WIKI_ROOT = wiki_root;
  };

  programs.fish.shellAliases = {
    wiki = "core wiki";
    task = "core task";
    tt = "core task interactive";
  };
}
