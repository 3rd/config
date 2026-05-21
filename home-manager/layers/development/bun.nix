{ ... }:

{
  xdg.configFile.".bunfig.toml".text = ''
    telemetry = false

    [install]
    ignoreScripts = true
    minimumReleaseAge = 604800
    exact = true
    linker = "isolated"
    globalStore = true
    frozenLockfile = false
    auto = "disable"
  '';
}
