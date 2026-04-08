{ lib }:
{
  watchPaths,
  excludePaths ? [ ],
  enableFs ? true,
  enableExec ? true,
  enableConnect ? true,
  extraRules ? [ ],
}:
let
  arches = [ "b64" "b32" ];

  isNestedUnder =
    parent: child:
    child == parent || lib.hasPrefix "${parent}/" child;

  isHomePath = path: lib.hasPrefix "/home/" path;

  mkDirRules =
    action: path: key:
    map (
      arch:
      if key == null then
        "-a ${action},exit -F arch=${arch} -F dir=${path} -F perm=wa"
      else
        "-a ${action},exit -F arch=${arch} -F dir=${path} -F perm=wa -k ${key}"
    ) arches;

  filteredWatchPaths = lib.unique (lib.filter builtins.pathExists watchPaths);
  filteredExcludePaths = lib.unique (
    lib.filter (
      exclude:
      builtins.pathExists exclude && lib.any (watch: isNestedUnder watch exclude) filteredWatchPaths
    ) excludePaths
  );
in
  lib.flatten (
    (lib.concatMap (path: mkDirRules "never" path null) filteredExcludePaths)
    ++ (lib.optionals enableExec [
      "-a always,exit -F arch=b64 -S execve -S execveat -k exec"
      "-a always,exit -F arch=b32 -S execve -S execveat -k exec"
    ])
    ++ (lib.optionals enableConnect [
      "-a always,exit -F arch=b64 -S connect -k net_connect"
      "-a always,exit -F arch=b32 -S connect -k net_connect"
    ])
    ++ (lib.optionals enableFs (
      lib.concatMap (
        path: mkDirRules "always" path (if isHomePath path then "fs_home" else "fs_system")
      ) filteredWatchPaths
    ))
    ++ [ extraRules ]
  )
