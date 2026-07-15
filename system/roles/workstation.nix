{
  config,
  lib,
  pkgs,
  ...
}:

let
  keyringDaemon = "${config.security.wrapperDir}/gnome-keyring-daemon";
  dbusUpdateActivationEnvironment = "${lib.getBin pkgs.dbus}/bin/dbus-update-activation-environment";
  resourcePressureSnapshot = pkgs.writeShellApplication {
    name = "resource-pressure-snapshot";
    runtimeInputs = with pkgs; [
      coreutils
      config.virtualisation.docker.package
      gawk
      procps
      systemd
      util-linux
    ];
    text = ''
      snapshot_dir="''${RESOURCE_PRESSURE_SNAPSHOT_DIR:-/tmp/resource-pressure-snapshots}"
      timestamp="$(date +%Y%m%d-%H%M%S)"
      snapshot="$snapshot_dir/$timestamp.txt"

      mkdir -p "$snapshot_dir"

      {
        echo "# resource pressure snapshot $timestamp"

        echo
        echo "## uptime"
        uptime

        echo
        echo "## memory"
        free -h

        echo
        echo "## vmstat"
        vmstat 1 5

        echo
        echo "## pressure"
        for pressure in cpu memory io; do
          echo "### $pressure"
          cat "/proc/pressure/$pressure" || true
        done

        echo
        echo "## top cpu"
        ps -eo pid,ppid,stat,pcpu,pmem,rss,comm,args --sort=-pcpu | head -n 40 || true

        echo
        echo "## top memory"
        ps -eo pid,ppid,stat,pcpu,pmem,rss,comm,args --sort=-rss | head -n 40 || true

        echo
        echo "## blocked tasks"
        ps -eo pid,ppid,stat,wchan:32,comm,args | awk '$3 ~ /D/ { print }' | head -n 80 || true

        echo
        echo "## oomd"
        oomctl || true

        if timeout 3s docker info >/dev/null 2>&1; then
          echo
          echo "## docker stats"
          timeout 5s docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}' || true
        fi
      } > "$snapshot"

      printf '%s\n' "$snapshot"
    '';
  };
  userSliceResourcePolicy = {
    CPUWeight = 80;
    IOWeight = 80;
    TasksMax = 131072;
  };
  dockerSliceResourcePolicy = {
    CPUWeight = 60;
    IOWeight = 40;
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "50%";
    MemoryHigh = "30%";
    MemoryMax = "35%";
    TasksMax = 32768;
  };
in

{
  imports = [
    ../modules/base.nix
    ../modules/android.nix
    ../modules/audio.nix
    ../modules/bluetooth.nix
    ../modules/xorg.nix
    ../modules/fonts.nix
    ../modules/thunar.nix
    ../modules/xfce4-notifyd.nix
    ../modules/virtualisation.nix
    ../../condom/modules/condom.nix
  ];

  programs.condom = {
    enable = true;
    binaryPath = "/home/rabbit/.local/bin/condom";
    helperBinaryPath = "/home/rabbit/.local/bin/condom-helper";
    installPackage = false;
    installSandboxTools = true;
  };

  users.users.rabbit.extraGroups = [
    config.programs.condom.helperGroup
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_queued_events" = 32768;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;

    "vm.dirty_background_bytes" = 268435456;
    "vm.dirty_bytes" = 1073741824;
    "vm.dirty_expire_centisecs" = 1000;
    "vm.dirty_writeback_centisecs" = 500;

    "net.core.rmem_max" = 67108864;
    "net.core.wmem_max" = 67108864;
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 65536 33554432";
    "net.ipv4.tcp_tw_reuse" = true;
    "net.core.netdev_max_backlog" = 8388608;
    "net.core.somaxconn" = 8388608;
    "net.ipv4.tcp_max_orphans" = 32768;

    "net.ipv6.conf.default.disable_ipv6" = true;
    "net.ipv6.conf.all.disable_ipv6" = true;
  };
  # systemd.extraConfig = "DefaultLimitNOFILE=1048576";
  systemd = {
    user = {
      settings.Manager = {
        DefaultLimitNOFILE = 1048576;
        DefaultCPUAccounting = true;
        DefaultMemoryAccounting = true;
        DefaultTasksAccounting = true;
        DefaultIOAccounting = true;
      };
      slices.docker.sliceConfig = dockerSliceResourcePolicy;
    };
    slices = {
      user.sliceConfig = userSliceResourcePolicy;
      docker.sliceConfig = dockerSliceResourcePolicy;
    };
    services = {
      fstrim.serviceConfig = {
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        IOWeight = 10;
      };
      nix-gc.serviceConfig = {
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        IOWeight = 10;
      };
      nix-optimise.serviceConfig = {
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        IOWeight = 10;
      };
    };
  };

  environment.systemPackages = [
    resourcePressureSnapshot
  ]
  ++ (with pkgs; [
    acpi
    appimage-run
    bluez
    coreutils
    fd
    fzf
    git
    tree
    glib
    gnumake
    graphviz
    # imhex
    inotify-tools
    iotop
    libfaketime
    libnotify
    moreutils
    openssl
    pciutils
    ripgrep
    unzip
    usbutils
    vim
    wget
    whois
    zip
    s-tui
    memtester
    udiskie
    (pkgs.buildFHSEnv (
      pkgs.appimageTools.defaultFhsEnvArgs
      // {
        name = "fhs";
        profile = "export FHS=1";
        runScript = "fish";
      }
    ))

    libx11.dev
    libxcursor.dev
    libxi.dev
    libxrandr.dev
    libGL.dev
    lm_sensors
    socat
    bubblewrap
    nsjail
    pstree
  ]);
  environment.variables.EDITOR = "vim";

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = true;
      config.common.default = "gtk";
    };
  };

  programs.dconf.enable = true;
  programs.firejail.enable = true;
  programs.nm-applet.enable = true;
  programs.sysdig.enable = true;

  services.dbus = {
    enable = true;
    # TODO: remove this and switch to dbus-broker with nixos-rebuild boot + reboot.
    implementation = "dbus";
    packages = [
      pkgs.gcr
      pkgs.gnome-keyring
    ];
  };

  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;
  programs.ssh.startAgent = true;
  security.pam.services = {
    login.enableGnomeKeyring = true;
    lightdm.enableGnomeKeyring = true;
  };
  services.xserver.displayManager = {
    lightdm.enable = lib.mkDefault true;
    defaultSession = lib.mkDefault "home-manager";
    session = lib.mkAfter [
      {
        name = "home-manager";
        manage = "desktop";
        start = ''
          ${pkgs.runtimeShell} $HOME/.hm-xsession &
          waitPID=$!
        '';
      }
    ];
    sessionCommands = lib.mkAfter ''
      if [ -z "''${GNOME_KEYRING_CONTROL:-}" ] || [ ! -S "''${GNOME_KEYRING_CONTROL}/control" ]; then
        eval "$(${keyringDaemon} --start --components=secrets,pkcs11)"
      fi

      systemctl --user import-environment GNOME_KEYRING_CONTROL GNOME_KEYRING_PID
      ${dbusUpdateActivationEnvironment} --systemd \
        DBUS_SESSION_BUS_ADDRESS \
        DISPLAY \
        GNOME_KEYRING_CONTROL \
        GNOME_KEYRING_PID \
        XAUTHORITY \
        XDG_RUNTIME_DIR
    '';
  };

  services.flatpak.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.opensnitch = {
    enable = true;
    settings.DefaultAction = "deny";
  };
  services.timesyncd.enable = lib.mkDefault true;
  services.udisks2.enable = true;

  services.atd.enable = true;
  services.gvfs.enable = true; # trash, MTP
  services.logind.killUserProcesses = true;
  services.irqbalance.enable = true;
  # services.devmon.enable = true;

  # qt = {
  #   enable = true;
  #   platformTheme = "kde";
  # };
}
