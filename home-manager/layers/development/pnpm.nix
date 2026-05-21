{ ... }:

{
  home = {
    sessionPath = [ "$HOME/.pnpm" ];
    sessionVariables.PNPM_HOME = "$HOME/.pnpm";
  };

  xdg.configFile."pnpm/config.yaml".text = ''
    minimumReleaseAge: 10080
    minimumReleaseAgeStrict: true
    minimumReleaseAgeIgnoreMissingTime: false
    blockExoticSubdeps: true
    strictDepBuilds: true
    dangerouslyAllowAllBuilds: false
    verifyDepsBeforeRun: error
    trustPolicy: no-downgrade
    savePrefix: ""
  '';
}
