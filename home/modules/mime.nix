{ config, lib, pkgs, ... }:
let
  chrome = "google-chrome.desktop";
  zathura = "org.pwmt.zathura.desktop";
in
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # inode
      "inode/directory" = "org.kde.dolphin.desktop";
      # text
      "text/plain" = "nvim.desktop";
      # web
      "text/html" = chrome;
      "text/xml" = chrome;
      "application/xhtml+xml" = chrome;
      "application/x-extension-htm" = chrome;
      "application/x-extension-html" = chrome;
      "application/x-extension-shtml" = chrome;
      "application/x-extension-xhtml" = chrome;
      "application/x-extension-xht" = chrome;
      "x-scheme-handler/http" = chrome;
      "x-scheme-handler/https" = chrome;
      "x-scheme-handler/chrome" = chrome;
      # mail
      "x-scheme-handler/mailto" = "org.gnome.Evolution.desktop";
      # telegram
      "x-scheme-handler/tg" = "telegramdesktop.desktop";
      # media
      "image/*" = "imv-folder.desktop";
      "video/*" = "umpv.desktop";
      # archives
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/rar" = "org.gnome.FileRoller.desktop";
      "application/7z" = "org.gnome.FileRoller.desktop";
      "application/*tar" = "org.gnome.FileRoller.desktop";
      # zathura
      "application/pdf" = zathura;
      "application/postscript" = "org.pwmt.zathura.desktop";
      "application/vnd.comicbook+zip" = "org.pwmt.zathura.desktop";
      "application/vnd.comicbook-rar" = "org.pwmt.zathura.desktop";
      "application/vnd.ms-xpsdocument" = "org.pwmt.zathura.desktop";
      "application/x-bzpdf" = "org.pwmt.zathura.desktop";
      "application/x-ext-djv" = "org.pwmt.zathura.desktop";
      "application/x-ext-djvu" = "org.pwmt.zathura.desktop";
      "application/x-ext-eps" = "org.pwmt.zathura.desktop";
      "application/x-ext-pdf" = "org.pwmt.zathura.desktop";
      "application/x-gzpdf" = "org.pwmt.zathura.desktop";
      "application/x-xzpdf" = "org.pwmt.zathura.desktop";
      "image/tiff" = "org.pwmt.zathura.desktop";
      "image/vnd.djvu+multipage" = "org.pwmt.zathura.desktop";
      "image/x-bzeps" = "org.pwmt.zathura.desktop";
      "image/x-eps" = "org.pwmt.zathura.desktop";
      "image/x-gzeps" = "org.pwmt.zathura.desktop";
    };
  };
}
