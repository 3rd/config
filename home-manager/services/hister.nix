{ inputs, ... }:

{
  imports = [ inputs.hister.homeModules.default ];

  services.hister.enable = true;
}
