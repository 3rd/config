let
  browserDesktop = "google-chrome.desktop";
  zathura = "org.pwmt.zathura.desktop";
in {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # inode
      "inode/directory" = "pcmanfm-qt.desktop";
      # text
      "text/plain" = "nvim.desktop";
      # mail
      "x-scheme-handler/mailto" = "";
      # telegram
      "x-scheme-handler/tg" = "telegramdesktop.desktop";
      # media
      "image/png" = "qimgv.desktop";
      "image/jpeg" = "qimgv.desktop";
      "image/gif" = "qimgv.desktop";
      # archives
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/rar" = "org.gnome.FileRoller.desktop";
      "application/7z" = "org.gnome.FileRoller.desktop";
      "application/tar" = "org.gnome.FileRoller.desktop";
      # zathura
      "application/pdf" = zathura;
      "application/postscript" = zathura;
      "application/vnd.comicbook+zip" = zathura;
      "application/vnd.comicbook-rar" = zathura;
      "application/vnd.ms-xpsdocument" = zathura;
      "application/x-bzpdf" = zathura;
      "application/x-ext-djv" = zathura;
      "application/x-ext-djvu" = zathura;
      "application/x-ext-eps" = zathura;
      "application/x-ext-pdf" = zathura;
      "application/x-gzpdf" = zathura;
      "application/x-xzpdf" = zathura;
      "image/tiff" = zathura;
      "image/vnd.djvu+multipage" = zathura;
      "image/x-bzeps" = zathura;
      "image/x-eps" = zathura;
      "image/x-gzeps" = zathura;
      # browser
      "application/xhtml+xml" = browserDesktop;
      "application/x-extension-htm" = browserDesktop;
      "application/x-extension-html" = browserDesktop;
      "application/x-extension-shtml" = browserDesktop;
      "application/x-extension-xht" = browserDesktop;
      "application/x-extension-xhtml" = browserDesktop;
      "text/html" = browserDesktop;
      "text/xml" = browserDesktop;
      "x-scheme-handler/about" = browserDesktop;
      "x-scheme-handler/chrome" = browserDesktop;
      "x-scheme-handler/http" = browserDesktop;
      "x-scheme-handler/https" = browserDesktop;
      "x-scheme-handler/unknown" = browserDesktop;
    };
  };

  xdg.configFile."mimeapps.list".force = true;
}
