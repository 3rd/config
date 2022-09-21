{ pkgs, ... }:

let
  vault_path = "$HOME/brain/storage/vault.encfs";
  mount_path = "$HOME/brain/storage/vault";
in
{
  home.packages = with pkgs; [ encfs ];

  home.file = {
    ".local/bin/vault-mount" = {
      executable = true;
      source = pkgs.substituteAll {
        src = ./vault-mount.sh;
        vault_path = "${vault_path}";
        mount_path = "${mount_path}";
      };
    };
    ".local/bin/vault-unmount" = {
      executable = true;
      source = pkgs.substituteAll {
        src = ./vault-unmount.sh;
        mount_path = "${mount_path}";
      };
    };
    ".local/bin/vault-passwd" = {
      executable = true;
      source = pkgs.substituteAll {
        src = ./vault-passwd.sh;
        vault_path = "${vault_path}";
      };
    };
  };
}
