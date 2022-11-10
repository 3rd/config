{ config, pkgs, ... }:

{
  programs.atuin = {
    enable = false;
    settings = {
      auto_sync = false;
      update_check = false;
      search_mode = "fuzzy";
      db_path = "~/brain/storage/data/atuin/history.db";
      key_path = "~/brain/storage/data/atuin/key";
      session_path = "~/brain/storage/data/atuin/session";
      # sync_address = "https://api.atuin.sh";
      # sync_frequency = "5m";
    };
  };
}
