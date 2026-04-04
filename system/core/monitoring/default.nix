{ config, lib, ... }:
let
  cfg = config.core.monitoring;
  isAbsolutePath = path: lib.hasPrefix "/" path;
  normalUserHomes = lib.pipe config.users.users [
    builtins.attrValues
    (builtins.filter (
      user:
        (user.isNormalUser or false)
        && user ? home
        && isAbsolutePath user.home
    ))
    (map (user: user.home))
    lib.unique
  ];
  homeCacheExcludePaths = map (home: "${home}/.cache") normalUserHomes;
in {
  imports = [
    ./options.nix
    ./packages.nix
    ./journald.nix
    ./auditd.nix
    ./collectors.nix
    ./loki.nix
    ./prometheus.nix
    ./alloy.nix
    ./grafana.nix
  ];

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.all isAbsolutePath cfg.paths.watch;
          message = "core.monitoring.paths.watch must contain absolute paths.";
        }
        {
          assertion = lib.all isAbsolutePath cfg.paths.exclude;
          message = "core.monitoring.paths.exclude must contain absolute paths.";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      core.monitoring.paths.exclude = lib.mkAfter homeCacheExcludePaths;
    })
  ];
}
