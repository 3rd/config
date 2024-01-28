{
  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_color_autosuggestion brblack

      # add bin to $PATH
      for bin_dir in $HOME/.config/bin/*/
        path_add $bin_dir
      end

      # fix NIX_PATH over ssh
      set -x NIX_PATH $HOME/.nix-defexpr/channels $NIX_PATH

      # fix nix+tmuxp+python
      set path (echo "$PATH" | sed "s/\\:[^\\:]*python3[^\\:]*\\:/:/g")
      set -x PATH "$path"

      # bun
      set -x BUN_INSTALL "$HOME/.bun"
      set -x PATH $BUN_INSTALL/bin $PATH

      ulimit -n 999999

      # zoxide init fish | source
      # navi widget fish | source
    '';
    functions = {
      fish_greeting.body = "";
      path_add = {
        description = "Add a path to $PATH.";
        body = "set -x PATH $argv $PATH";
      };
      mkd = {
        description = "Create a directory and cd into it.";
        body = "mkdir -p $argv[1]; cd $argv[1]";
      };
      mkdate = {
        description = "Create a directory with the current date.";
        body = ''
          set date (date '+%Y-%m-%d')
          mkdir -p $date;
        '';
      };
      fkill = {
        description = "Fuzzy process killer.";
        body = ''
          set -l __kp__pid (ps -ef | sed 1d | eval "fzf -m --header='[kill:process]'" | awk '{print $2}')
          set -l __kp__kc $argv[1]
          if test "x$__kp__pid" != "x"
            if test "x$argv[1]" != "x"
              echo $__kp__pid | xargs kill $argv[1]
            else
              echo $__kp__pid | xargs kill -9
            end
          end
        '';
      };
      work = {
        description = "Work manager";
        body = ''
          begin
            set -l IFS
            set output (/home/rabbit/brain/projects/tools/git-work/work $argv);
          end
          switch $output
            case "*-> *"
            cd (echo $output | rg "\->" | sed "s/-> //g")
          end
          echo $output | rg -v "\->"
        '';

      };
    };
    shellAliases = {
      # core
      q = "exit";
      v = "nvim";
      # shell utils
      ".." = "cd ..";
      mv = "mv -v";
      mkdir = "mkdir -pv";
      vd = "vidir";
      vdd = "find | vidir -";
      # bookmarks
      "@b" = "cd ~/brain";
      "@c" = "cd ~/brain/config";
      "@w" = "cd ~/brain/wiki";
      "@p" = "cd ~/brain/projects";
      "@l" = "cd ~/lab";
      "@bin" = "cd ~/brain/config/home/bin";
      "@core" = "cd ~/brain/core";
      "@work" = "cd ~/brain/work";
      # custom utils
      w = "work";
      # wiki
      p = "v ~/brain/wiki/plan";
      ti = "v ~/brain/wiki/_inbox/tasks";
      tl = "v ~/brain/wiki/_inbox/links";
      bookmarks = "v ~/brain/wiki/bookmarks";
    };
  };
}
