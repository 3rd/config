{ pkgs, ... }:

let
  scripts = {
    git-id = pkgs.writeShellScriptBin "git-id" (builtins.readFile ./git-id.sh);
    git-branch =
      pkgs.writeShellScriptBin "git-branch" (builtins.readFile ./git-branch.sh);
    git-undo =
      pkgs.writeShellScriptBin "git-undo" (builtins.readFile ./git-undo.sh);
    git-status-deep = pkgs.writeShellScriptBin "git-status-deep"
      (builtins.readFile ./git-status-deep.sh);
    git-standup = pkgs.writeShellScriptBin "git-standup"
      (builtins.readFile ./git-standup.sh);
  };
in {
  imports = [ ./private.nix ];

  home.packages = with pkgs; [
    blackbox
    commit-formatter
    git-crecord
    git-sizer
    gitstats
    gource
    lazygit
    meld
    sublime-merge
    gh
    smartgit
    # custom
    scripts.git-branch
    scripts.git-id
    scripts.git-undo
    scripts.git-status-deep
    scripts.git-standup
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
      enable = false;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
        features = "decorations";
        whitespace-error-style = "22 reverse";
      };
    };
    difftastic = {
      enable = true;
      options = { background = "dark"; };
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
      pull = { rebase = true; };
      push = { default = "simple"; };
      rebase = { autoStash = true; };
    };
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
    stash = "git stash";
    gl =
      "git log --graph --pretty=format:'%Cred%h%Creset %s - %C(bold blue)%an%Creset %Cgreen(%cr)' --abbrev-commit";
    gll = "git log --graph --abbrev-commit --decorate";
    # gstandup = ''
    #   git log  --all --author="$(git config user.email)" --pretty=format:'%h %ad %s | %an' --date=short -62 '';
    # scripts
    gid = "git-id";
    gbr = "git-branch";
    gstandup = "git-standup";
    gsd = "git-status-deep";
  };
  programs.fish.shellAbbrs = { };
}
