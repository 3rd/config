{ config, ... }:

{
  xdg.dataFile."themes/Config/xfce-notify-4.0/gtk.css".text = ''
    #XfceNotifyWindow {
      background-color: ${config.colors.gray-darkest};
      color: ${config.colors.foreground};
      border: none;
      border-radius: 6px;
      box-shadow: none;
      padding: 12px;
    }

    #XfceNotifyWindow:hover {
      background-color: ${config.colors.gray-darker};
    }

    #XfceNotifyWindow label,
    #XfceNotifyWindow image {
      color: ${config.colors.foreground};
    }

    #XfceNotifyWindow label#summary {
      font-weight: 600;
    }

    #XfceNotifyWindow label#body {
      color: ${config.colors.gray-lightest};
    }

    #XfceNotifyWindow button {
      background-image: none;
      background-color: ${config.colors.gray-darker};
      color: ${config.colors.foreground};
      border: none;
      border-radius: 4px;
      box-shadow: none;
      text-shadow: none;
    }

    #XfceNotifyWindow button:hover {
      background-image: none;
      background-color: ${config.colors.gray-dark};
      color: ${config.colors.foreground};
      border: none;
      box-shadow: none;
    }

    #XfceNotifyWindow progressbar {
      min-height: 4px;
    }

    #XfceNotifyWindow progressbar trough {
      background-image: none;
      background-color: ${config.colors.gray-dark};
      border: none;
      border-radius: 2px;
    }

    #XfceNotifyWindow progressbar progress {
      background-image: none;
      background-color: ${config.colors.accent};
      border: none;
      border-radius: 2px;
    }
  '';

  xfconf.settings.xfce4-notifyd = {
    "theme" = "Config";
    "initial-opacity" = 1.0;
    "show-notifications-on" = "active-monitor";
    "notify-location" = "top-right";
    "notification-log" = true;
    "log-level" = "always";
    "log-level-apps" = "all";
    "log-max-size-enabled" = true;
    "log-max-size" = {
      type = "uint";
      value = 1000;
    };
  };
}
