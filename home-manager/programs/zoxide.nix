{
  programs.zoxide.enable = true;

  programs.fish = {
    functions = {
      zz = {
        body = ''
          set path (zoxide query -l | fzf --preview 'zoxide query {}')
          if test -n "$path"
            cd "$path"
          end
        '';
      };
    };
    shellAliases = { zq = "zoxide query -l"; };
  };
}

