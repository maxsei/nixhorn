{ pkgs }:
pkgs.buildGoModule {
  pname = "nixhorn-webhook";
  version = builtins.readFile VERSION;
  src = ./src;
  vendorHash = "sha256-qVSUymTDYc2caXEUW6jmJ8July11xLuvmYGndjBpk58=";
  ldflags = [
    "-s"
    "-w"
  ];
  env.CGO_ENABLED = "0";
}
