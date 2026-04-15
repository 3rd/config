{ pkgs, ... }:

let
  ghCrate =
    {
      owner,
      repo,
      rev,
      hash,
      cargoHash,
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      cargoPatches ? [ ],
      env ? { },
    }:
    pkgs.rustPlatform.buildRustPackage (
      {
        pname = repo;
        version = rev;
        src = pkgs.fetchFromGitHub {
          inherit
            owner
            repo
            rev
            hash
            ;
        };
        inherit
          cargoHash
          nativeBuildInputs
          buildInputs
          cargoPatches
          ;
        doCheck = false;
      }
      // env
    );
in
{
  home.packages = with pkgs; [
    rustup

    # (ghCrate {
    #   owner = "";
    #   repo = "";
    #   rev = "v0.1.0";
    #   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    #   cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # })

    # (ghCrate {
    #   owner = "BeaconBay";
    #   repo = "ck";
    #   rev = "15c35d940c52220f421ecc3a46b1889064da6cd7";
    #   hash = "sha256-JL6P1YdeoesdHbWO59r8TzF0lUMd91WJsHvLRhSm2FM=";
    #   cargoHash = "sha256-WxJb7YBrwrnxRVCQ/pyU6qIAJTFt3sSMPrRVrrdw74c=";
    #   nativeBuildInputs = [
    #     perl
    #     pkg-config
    #   ];
    #   buildInputs = [
    #     openssl
    #     onnxruntime
    #   ];
    #   env = {
    #     ORT_STRATEGY = "system";
    #     ORT_LIB_LOCATION = "${onnxruntime}";
    #   };
    # })
  ];

  home.sessionPath = [ "$HOME/.cargo/bin" ];
  programs.fish = {
    shellInit = ''
      set -x PATH $HOME/.cargo/bin $PATH
    '';
  };
}
