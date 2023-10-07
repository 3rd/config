{ pkgs, ... }:

let
  scripts = {
    git-id = pkgs.writeShellScriptBin "git-id" (builtins.readFile ./git-id.sh);
    git-branch =
      pkgs.writeShellScriptBin "git-branch" (builtins.readFile ./git-branch.sh);
    git-undo =
      pkgs.writeShellScriptBin "git-undo" (builtins.readFile ./git-undo.sh);
  };
in {
  imports = [ ./private.nix ];

  home.packages = with pkgs; [
    blackbox
    commit-formatter
    git-backup
    git-crecord
    git-sizer
    gitstats
    gource
    lazygit
    meld
    sublime-merge
    # custom
    scripts.git-branch
    scripts.git-id
    scripts.git-undo
  ];

  programs.git = {
    enable = true;
    aliases = {
      undo = ''
        !f() {\
          git-undo; \
        }; f
      '';
    };
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
        features = "decorations";
        whitespace-error-style = "22 reverse";
      };
    };
    extraConfig = {
      init.defaultBranch = "master";
      color.ui = true;
      gc = {
        reflogExpire = 200;
        reflogExpireUnreachable = 90;
      };
      core = {
        autocrlf = "input";
        editor = "nvim";
      };
      diff = {
        algorithm = "histogram";
        renameLimit = 2048;
        renames = "copy";
      };
      merge = { tool = "meld"; };
      mergetool.meld = {
        cmd = ''
          ${pkgs.meld}/bin/meld "$LOCAL" "$BASE" "$REMOTE" --output "$MERGED"'';
      };
      # blame = { ignoreRevsFile = ".git-blame-ignore-revs"; };
      pull = { rebase = false; };
      push = { default = "simple"; };
    };
  };

  programs.fish.shellAbbrs = {
    gl =
      "git log --graph --pretty=format:'%Cred%h%Creset %s - %C(bold blue)%an%Creset %Cgreen(%cr)' --abbrev-commit";
    gll = "git log --graph --abbrev-commit --decorate";
  };
  programs.fish.shellAliases = {
    g = "git";
    ga = "git add";
    gc = "git commit";
    gs = "git status -sb";
    gd = "git diff";
    gaa = "git add --all";
    gac = "git add . && git commit";
    clone = "git clone";
    fetch = "git fetch";
    pull = "git pull";
    push = "git push";
    rebase = "git rebase";
    merge = "git merge";
    # scripts
    gid = "git-id";
    gbr = "git-branch";
    gstandup = ''
      git log  --all --author="$(git config user.email)" --pretty=format:'%h %ad %s | %an' --date=short -62
    '';
  };
}
