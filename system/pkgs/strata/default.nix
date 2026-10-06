{
  lib,
  fetchzip,
  cudaPackages_13_0,
  cmake,
  ninja,
  autoAddDriverRunpath,
  makeWrapper,
  python3,
}:

let
  version = "0.1.39";
  cudaPackages = cudaPackages_13_0;
  llamaSource = fetchzip {
    url = "https://codeload.github.com/ggml-org/llama.cpp/tar.gz/3cf03257f219afbe7334045ff7c6a06ac68c627d";
    extension = "tar.gz";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
  };
  pythonEnv = python3.withPackages (
    ps: with ps; [
      numpy
      jinja2
      regex
      pyyaml
      tqdm
      requests
      pillow
      psutil
    ]
  );
  cudaLibraryDirs = [
    "${lib.getLib cudaPackages.cuda_cudart}/lib"
    "${lib.getLib cudaPackages.libcublas}/lib"
  ];
in
cudaPackages.backendStdenv.mkDerivation {
  pname = "strata";
  inherit version;
  src = fetchzip {
    url = "https://codeload.github.com/Niko1221/Strata/tar.gz/6f32ec070f23ced9f50e704d854d775da52591ab";
    extension = "tar.gz";
    hash = "sha256-9jqmV+AbGKiOqW1DvKjqBLVXmJCI9o6WI85QoHj5vBI=";
  };
  patches = [
    ./nix-setup.patch
    ./calibration-fit.patch
  ];

  nativeBuildInputs = [
    cmake
    ninja
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
    makeWrapper
  ];
  buildInputs = [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];
  cmakeFlags = [
    "-DSTRATA_ENABLE_CUDA=ON"
    "-DSTRATA_BUILD_TESTS=OFF"
    "-DSTRATA_PORTABLE=ON"
    "-DCMAKE_CUDA_ARCHITECTURES=120"
    "-DCMAKE_CUDA_RUNTIME_LIBRARY=Shared"
    "-DSTRATA_GGML_DIR=${llamaSource}"
  ];
  ninjaFlags = [ "strata" ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pushd .. >/dev/null
    ${pythonEnv}/bin/python -B -m unittest tools.test_calibrate serve.test_server.RestartWindow serve.test_server.StartFailureLog -q
    popd >/dev/null
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/libexec/strata" "$out/share/strata"
    cp strata "$out/libexec/strata/strata"
    cp -r ../serve ../tools ../data "$out/share/strata/"
    cp ../setup.py ../CMakeLists.txt "$out/share/strata/"
    cat > "$out/libexec/strata/BUILD.json" <<EOF
    ${builtins.toJSON {
      source = "local";
      inherit version;
      archs = [ 120 ];
      vision = "none";
      lib_dirs = cudaLibraryDirs;
    }}
    EOF

    makeWrapper ${pythonEnv}/bin/python "$out/bin/strata-server" \
      --add-flags "$out/share/strata/serve/server.py --engine strata" \
      --set PYTHONUNBUFFERED 1 \
      --set PYTHONDONTWRITEBYTECODE 1
    makeWrapper ${pythonEnv}/bin/python "$out/bin/strata-setup" \
      --add-flags "$out/share/strata/setup.py --setup --no-start" \
      --set STRATA_ENGINE_DIR "$out/libexec/strata" \
      --set STRATA_LLAMA_DIR ${llamaSource} \
      --set STRATA_ASSETS_DIR "$out/share/strata" \
      --set PYTHONUNBUFFERED 1 \
      --set PYTHONDONTWRITEBYTECODE 1
    runHook postInstall
  '';

  meta = {
    description = "Strata CUDA inference engine and local API for Qwen3.8-Flash-Next";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata-server";
  };
}
