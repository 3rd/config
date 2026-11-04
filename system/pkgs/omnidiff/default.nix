{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "omnidiff";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/ivankovic/omnidiff/releases/download/v${finalAttrs.version}/omnidiff-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-yF7FwvkxpSx3q6NCEbPF3jdxEugJi98CoBZQOFatoa4=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ installShellFiles ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 omnidiff "$out/bin/omnidiff"
    "$out/bin/omnidiff" util man > omnidiff.1
    installManPage omnidiff.1
    installShellCompletion --cmd omnidiff \
      --bash <("$out/bin/omnidiff" util completions bash) \
      --zsh <("$out/bin/omnidiff" util completions zsh) \
      --fish <("$out/bin/omnidiff" util completions fish)

    runHook postInstall
  '';

  meta = {
    description = "Content-aware diff tool with an interactive terminal viewer";
    homepage = "https://github.com/ivankovic/omnidiff";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "omnidiff";
  };
})
