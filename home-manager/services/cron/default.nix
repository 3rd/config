{
  lib,
  pkgs,
  ...
}:

let
  cronsDir = ./crons;
  cronsDirEntries = builtins.readDir cronsDir;
  cronSpecNames = builtins.attrNames (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name) cronsDirEntries
  );

  requiredString =
    fileName: fieldName: raw:
    if !(builtins.hasAttr fieldName raw) then
      throw "${fileName}: missing required field `${fieldName}`"
    else
      let
        value = builtins.getAttr fieldName raw;
      in
      if builtins.isString value && value != "" then
        value
      else
        throw "${fileName}: field `${fieldName}` must be a non-empty string";

  optionalString =
    fileName: fieldName: default: raw:
    if builtins.hasAttr fieldName raw then requiredString fileName fieldName raw else default;

  optionalBool =
    fileName: fieldName: default: raw:
    if !(builtins.hasAttr fieldName raw) then
      default
    else
      let
        value = builtins.getAttr fieldName raw;
      in
      if builtins.isBool value then
        value
      else
        throw "${fileName}: field `${fieldName}` must be a boolean";

  formatSuccessExitStatus =
    fileName: raw:
    if !(builtins.hasAttr "successExitStatus" raw) then
      null
    else
      let
        value = raw.successExitStatus;
        statuses =
          if builtins.isList value then
            map (
              status:
              if builtins.isInt status || builtins.isString status then
                builtins.toString status
              else
                throw "${fileName}: field `successExitStatus` entries must be strings or integers"
            ) value
          else
            throw "${fileName}: field `successExitStatus` must be a list";
      in
      if statuses == [ ] then null else lib.concatStringsSep " " statuses;

  resolveScript =
    fileName: script:
    let
      relativeScript = lib.removePrefix "./" script;
      scriptPath = cronsDir + "/${relativeScript}";
    in
    if !(lib.hasPrefix "./" script) then
      throw "${fileName}: field `script` must be relative to the TOML file, for example `./job.sh`"
    else if
      relativeScript == "" || lib.hasPrefix ".." relativeScript || lib.hasInfix "/../" relativeScript
    then
      throw "${fileName}: field `script` must not escape the crons directory"
    else if !(builtins.pathExists scriptPath) then
      throw "${fileName}: script `${script}` does not exist"
    else
      scriptPath;

  loadJob =
    fileName:
    let
      specPath = cronsDir + "/${fileName}";
      raw = builtins.fromTOML (builtins.readFile specPath);
      name = requiredString fileName "name" raw;
      script = requiredString fileName "script" raw;
      onCalendar = requiredString fileName "onCalendar" raw;
    in
    {
      inherit name onCalendar;
      description = optionalString fileName "description" "${name}: scheduled user job" raw;
      timerDescription = optionalString fileName "timerDescription" "Run ${name}" raw;
      persistent = optionalBool fileName "persistent" true raw;
      successExitStatus = formatSuccessExitStatus fileName raw;
      scriptPath = resolveScript fileName script;
      source = fileName;
    };

  jobs = map loadJob cronSpecNames;
  jobNames = map (job: job.name) jobs;
  duplicateJobNames = lib.unique (
    builtins.filter (
      name: builtins.length (builtins.filter (candidate: candidate == name) jobNames) > 1
    ) jobNames
  );

  checkedJobs =
    if duplicateJobNames != [ ] then
      throw "duplicate cron job names: ${lib.concatStringsSep ", " duplicateJobNames}"
    else
      jobs;

  checkedScript =
    job:
    pkgs.runCommand "${job.name}-cron-script"
      {
        src = job.scriptPath;
      }
      ''
        if [ ! -x "$src" ]; then
          echo "${job.source}: script $src must be executable" >&2
          exit 1
        fi

        if [ "$(head -c 2 "$src")" != "#!" ]; then
          echo "${job.source}: script $src must start with a shebang" >&2
          exit 1
        fi

        cp "$src" "$out"
        chmod +x "$out"
      '';

  mkService = job: {
    name = job.name;
    value = {
      Unit.Description = job.description;
      Service = {
        Type = "oneshot";
        ExecStart = "${checkedScript job}";
      }
      // lib.optionalAttrs (job.successExitStatus != null) {
        SuccessExitStatus = job.successExitStatus;
      };
    };
  };

  mkTimer = job: {
    name = job.name;
    value = {
      Unit.Description = job.timerDescription;
      Timer = {
        OnCalendar = job.onCalendar;
        Persistent = job.persistent;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
in
{
  systemd.user.services = builtins.listToAttrs (map mkService checkedJobs);
  systemd.user.timers = builtins.listToAttrs (map mkTimer checkedJobs);
}
