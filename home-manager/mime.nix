let zathura = "org.pwmt.zathura.desktop";
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
    };
  };
  xdg.configFile."mimeapps.list".force = true;
}
