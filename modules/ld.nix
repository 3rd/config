{ config, pkgs, pkgs-stable, lib, ... }:

{
  # boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  programs.nix-ld = {
    enable = true;
    libraries = [
      (pkgs.runCommand "steamrun-lib" { }
        "mkdir $out; ln -s ${pkgs.steam-run.fhsenv}/usr/lib64 $out/lib")
    ];
  };

  system.activationScripts.ldso = {
    deps = [ ];
    text = ''
      mkdir -p /lib64
      ln -sfn ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
    '';
  };
}
