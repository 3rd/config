{ pkgs, ... }:

{
  programs.fish.functions.fm = {
    description = "Open Thunar at a directory.";
    body = ''
      set -l directory $PWD
      if test (count $argv) -gt 0
        set directory $argv[1]
      end
      command thunar "$directory" >/dev/null 2>&1 &; disown
    '';
  };

  xdg.configFile."Thunar/uca.xml" = {
    force = true;
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <actions>
      <action>
        <icon>utilities-terminal</icon>
        <name>Open Terminal Here</name>
        <submenu></submenu>
        <command>${pkgs.kitty}/bin/kitty --directory %f</command>
        <description>Open a terminal in the selected directory</description>
        <patterns>*</patterns>
        <directories/>
      </action>
      <action>
        <icon>utilities-terminal</icon>
        <name>Edit in Neovim</name>
        <submenu></submenu>
        <command>${pkgs.kitty}/bin/kitty --directory %d nvim %F</command>
        <description>Open the selection in Neovim</description>
        <patterns>*</patterns>
        <directories/>
        <text-files/>
        <other-files/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Copy Path</name>
        <submenu></submenu>
        <command>${pkgs.bash}/bin/bash -c 'printf "%s\n" "$@" | ${pkgs.xclip}/bin/xclip -selection clipboard' thunar-copy-path %F</command>
        <description>Copy selected paths to the clipboard</description>
        <patterns>*</patterns>
        <directories/>
        <text-files/>
        <image-files/>
        <audio-files/>
        <video-files/>
        <other-files/>
      </action>
      <action>
        <icon>archive-extract</icon>
        <name>Extract Here</name>
        <submenu></submenu>
        <command>${pkgs.file-roller}/bin/file-roller --extract-here %F</command>
        <description>Extract archives into this folder</description>
        <patterns>*.7z;*.ace;*.alz;*.arc;*.arj;*.bz2;*.cab;*.gz;*.iso;*.jar;*.lha;*.lrz;*.lz;*.lz4;*.lzh;*.lzma;*.rar;*.tar;*.tar.bz2;*.tar.gz;*.tar.lz;*.tar.lz4;*.tar.lzma;*.tar.xz;*.tar.zst;*.tbz;*.tbz2;*.tgz;*.tlz;*.txz;*.zip;*.zst</patterns>
        <other-files/>
      </action>
      <action>
        <icon>archive-insert</icon>
        <name>Compress</name>
        <submenu></submenu>
        <command>${pkgs.file-roller}/bin/file-roller --add %F</command>
        <description>Create an archive from the selection</description>
        <patterns>*</patterns>
        <directories/>
        <text-files/>
        <image-files/>
        <audio-files/>
        <video-files/>
        <other-files/>
      </action>
      </actions>
    '';
  };

  xfconf.settings.thunar = {
    "default-view" = "ThunarDetailsView";
    "hidden-bookmarks" = [ "recent:///" ];
    "last-location-bar" = "ThunarLocationButtons";
    "last-restore-tabs" = true;
    "last-side-pane" = "THUNAR_SIDEPANE_TYPE_SHORTCUTS";
    "last-view" = "ThunarDetailsView";
    "last-show-hidden" = true;
    "last-sort-column" = "THUNAR_COLUMN_NAME";
    "last-sort-order" = "GTK_SORT_ASCENDING";
    "misc-folders-first" = true;
    "misc-full-path-in-tab-title" = true;
    "misc-image-preview-mode" = "THUNAR_IMAGE_PREVIEW_MODE_EMBEDDED";
    "misc-thumbnail-mode" = "THUNAR_THUMBNAIL_MODE_ONLY_LOCAL";
    "misc-remember-geometry" = true;
    "misc-volume-management" = true;
    "misc-open-new-window-as-tab" = true;
    "misc-middle-click-in-tab" = true;
    "misc-show-delete-action" = true;
    "misc-confirm-move-to-trash" = true;
    "misc-file-drag-mode" = "THUNAR_FILE_DRAG_MODE_MENU_CONDITIONAL";
    "shortcuts-icon-size" = "THUNAR_ICON_SIZE_24";
  };
}
