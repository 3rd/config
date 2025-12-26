{ config, pkgs, pkgs-stable, lib, ... }:

{
  # boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  # https://www.reddit.com/r/NixOS/comments/1d7zvgu/nvim_cant_find_standard_library_headers/
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs;
      [
        stdenv.cc.cc

        (runCommand "steamrun-lib" { }
          "mkdir $out; ln -s ${steam-run.fhsenv}/usr/lib64 $out/lib")
      ] ++ [ config.boot.kernelPackages.nvidia_x11 ];
  };

  system.activationScripts.ldso = {
    deps = [ ];
    text = ''
      mkdir -p /lib64
      ln -sfn ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
    '';
  };
}
