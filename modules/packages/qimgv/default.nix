{ lib, stdenv, fetchFromGitHub, cmake, pkg-config, libsForQt5, opencv4, exiv2
, mpv-unwrapped, }:

stdenv.mkDerivation {
  pname = "qimgv";
  version = "unstable-2024-07-27";
  src = fetchFromGitHub {
    owner = "easymodo";
    repo = "qimgv";
    rev = "82e6b7537002b86b4ab20954aab5bf0db7c25752";
    hash = "sha256-FboaMevbzsKZSfbalVI4Kwwgp4Lbct3KDE6xKufzGtc=";
  };

  nativeBuildInputs = [ cmake pkg-config libsForQt5.wrapQtAppsHook ];

  buildInputs = with libsForQt5; [
    exiv2
    kimageformats
    mpv-unwrapped
    opencv4
    qtbase
    qtimageformats
    qtsvg
    qttools
  ];

  cmakeFlags = [ "-DVIDEO_SUPPORT=ON" "-DEXIV2=ON" "-DOPENCV_SUPPORT=ON" ];
}
