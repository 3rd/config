{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "✗";
      };
      directory = {
        truncate_to_repo = true;
        truncation_length = 2;
      };
      git_status = { disabled = true; };
      git_commit = {
        commit_hash_length = 4;
        tag_symbol = "🔖 ";
      };
      git_branch = {
        truncation_length = 32;
        truncation_symbol = "…";
        symbol = " ";
        format = "[\\($symbol$branch\\)]($style) ";
        # ignore_branches = [ "master" "main" ];
      };
      cmd_duration = {
        min_time = 10;
        format = "[$duration](bold yellow) ";
      };
    };
  };
}
