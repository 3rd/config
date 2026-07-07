{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      scan_timeout = 120;
      follow_symlinks = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "✗";
      };
      directory = {
        truncate_to_repo = true;
        truncation_length = 2;
      };
      cmd_duration = {
        min_time = 0;
        show_milliseconds = true;
        format = "[$duration](bold yellow) ";
      };
      direnv = {
        disabled = false;
        format = "[$symbol$loaded/$allowed]($style) ";
        symbol = "󱁿 ";
        loaded_msg = "on";
        unloaded_msg = "off";
        allowed_msg = "ok";
        not_allowed_msg = "blocked";
        denied_msg = "denied";
        style = "bold yellow";
      };
      hostname = { ssh_only = true; };
      git_status = {
        disabled = false;
        format = "([$ahead_behind]($style) )";
        style = "bold cyan";
        ahead = "󰁝\${count}";
        behind = "󰁅\${count}";
        diverged = "󰃻\${ahead_count}/\${behind_count}";
      };
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
      status = {
        disabled = false;
        pipestatus = true;
        format = "[$symbol$status]($style) ";
        pipestatus_format = "[$symbol$pipestatus]($style) ";
        pipestatus_segment_format = "$status";
        pipestatus_separator = "|";
        symbol = "󰅚 ";
        style = "bold yellow";
      };
    };
  };
}
