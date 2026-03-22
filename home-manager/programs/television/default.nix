let
  channels = builtins.fromTOML (builtins.readFile ./channels.toml);
in
{
  programs.television = {
    enable = true;
    enableFishIntegration = true;
    inherit channels;
  };
}
