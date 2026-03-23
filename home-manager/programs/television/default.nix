let
  channels = builtins.fromTOML (builtins.readFile ./channels.toml);
in
{
  programs.television = {
    enable = true;
    enableFishIntegration = false;
    inherit channels;
  };
}
