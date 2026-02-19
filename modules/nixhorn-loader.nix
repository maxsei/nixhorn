{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixhorn-loader;
in
{
  options.services.nixhorn-loader = {
    enable = lib.mkEnableOption "nixhorn-loader";

    imagePackage = lib.mkOption {
      type = lib.types.package;
      description = "The container image package to load";
      default = pkgs.nixhorn-image;
    };

    after = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "network.target"
        "k3s.service"
      ];
      description = "Systemd units that must start before this service";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixhorn-loader = {
      description = "Load nixhorn-webhook image to containerd";
      wantedBy = [ "multi-user.target" ];
      after = cfg.after;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "containerd-load-nixhorn-image" ''
          ${pkgs.k3s}/bin/k3s ctr images import ${cfg.imagePackage}
        '';
      };
    };
  };
}
