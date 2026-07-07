{
  description = "Development shell for Condom";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      approvalGuiLibraries = with pkgs; [
        cairo
        fontconfig
        glib
        libx11
        libxcursor
        libxext
        libxfixes
        libxft
        libxinerama
        libxkbcommon
        libxrender
        pango
      ];
      approvalGuiLibraryPath = pkgs.lib.makeLibraryPath approvalGuiLibraries;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          bubblewrap
          cargo
          clippy
          cmake
          curl
          fence
          fuse-overlayfs
          gnumake
          nixfmt
          pkg-config
          rust-analyzer
          rustc
          rustfmt
          stdenv.cc
          util-linux
        ];

        buildInputs = approvalGuiLibraries;

        CONDOM_APPROVAL_NATIVE_LIB_DIRS = approvalGuiLibraryPath;
        LD_LIBRARY_PATH = approvalGuiLibraryPath;
        RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
