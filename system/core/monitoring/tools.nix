{ buildGoModule, lib }:
buildGoModule {
  pname = "core-monitoring-tools";
  version = "0.1.0";

  src = ./.;
  vendorHash = null;
  subPackages = [ "./cmd/core-monitoring-tools" ];
  ldflags = [
    "-s"
    "-w"
  ];

  meta.mainProgram = "core-monitoring-tools";
}
