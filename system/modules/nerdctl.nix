{ lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nerdctl
    buildkit
    cni-plugins
    containerd
    rootlesskit
    runc
    slirp4netns
  ];

  users.users.rabbit.linger = lib.mkDefault true;
}
