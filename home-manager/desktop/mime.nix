{ lib, ... }:

let
  browserDesktop = "google-chrome.desktop";
  claudeDesktop = "claude-desktop.desktop";
  libreOfficeCalc = "libreoffice-calc.desktop";
  libreOfficeDraw = "libreoffice-draw.desktop";
  libreOfficeImpress = "libreoffice-impress.desktop";
  libreOfficeWriter = "libreoffice-writer.desktop";
  zathura = "org.pwmt.zathura.desktop";
  defaultApplications = {
    "application/7z" = "org.gnome.FileRoller.desktop";
    "application/msword" = libreOfficeWriter;
    "application/pdf" = zathura;
    "application/postscript" = zathura;
    "application/rar" = "org.gnome.FileRoller.desktop";
    "application/rtf" = libreOfficeWriter;
    "application/tar" = "org.gnome.FileRoller.desktop";
    "application/vnd.comicbook+zip" = zathura;
    "application/vnd.comicbook-rar" = zathura;
    "application/vnd.ms-excel" = libreOfficeCalc;
    "application/vnd.ms-powerpoint" = libreOfficeImpress;
    "application/vnd.ms-xpsdocument" = zathura;
    "application/vnd.oasis.opendocument.graphics" = libreOfficeDraw;
    "application/vnd.oasis.opendocument.presentation" = libreOfficeImpress;
    "application/vnd.oasis.opendocument.spreadsheet" = libreOfficeCalc;
    "application/vnd.oasis.opendocument.text" = libreOfficeWriter;
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = libreOfficeImpress;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = libreOfficeCalc;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = libreOfficeWriter;
    "application/xhtml+xml" = browserDesktop;
    "application/x-bzpdf" = zathura;
    "application/x-extension-htm" = browserDesktop;
    "application/x-extension-html" = browserDesktop;
    "application/x-extension-shtml" = browserDesktop;
    "application/x-extension-xht" = browserDesktop;
    "application/x-extension-xhtml" = browserDesktop;
    "application/x-ext-djv" = zathura;
    "application/x-ext-djvu" = zathura;
    "application/x-ext-eps" = zathura;
    "application/x-ext-pdf" = zathura;
    "application/x-gzpdf" = zathura;
    "application/x-xzpdf" = zathura;
    "application/zip" = "org.gnome.FileRoller.desktop";
    "image/gif" = "qimgv.desktop";
    "image/jpeg" = "qimgv.desktop";
    "image/png" = "qimgv.desktop";
    "image/tiff" = zathura;
    "image/vnd.djvu+multipage" = zathura;
    "image/x-bzeps" = zathura;
    "image/x-eps" = zathura;
    "image/x-gzeps" = zathura;
    "inode/directory" = "thunar.desktop";
    "text/csv" = libreOfficeCalc;
    "text/html" = browserDesktop;
    "text/plain" = "nvim.desktop";
    "text/xml" = browserDesktop;
    "x-scheme-handler/about" = browserDesktop;
    "x-scheme-handler/chrome" = browserDesktop;
    "x-scheme-handler/claude" = claudeDesktop;
    "x-scheme-handler/http" = browserDesktop;
    "x-scheme-handler/https" = browserDesktop;
    "x-scheme-handler/mailto" = "";
    "x-scheme-handler/tg" = "telegramdesktop.desktop";
    "x-scheme-handler/unknown" = browserDesktop;
  };
  mimeappsList = lib.generators.toINI { } {
    "Default Applications" = lib.mapAttrs (
      _: desktopFile: if desktopFile == "" then "" else "${desktopFile};"
    ) defaultApplications;
  };
in
{
  xdg.dataFile."applications/mimeapps.list".text = mimeappsList;
}
