{
  pkgs,
  config,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/minimal.nix") ];

  microvm = {
    hypervisor = "qemu";
    mem = 4096;
    vcpu = 2;
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    volumes = [
      {
        mountPoint = "/var";
        size = 6144;
        image = ".microvms/microvm-var.ext4";
      }
      {
        mountPoint = "/root/.bash_history";
        size = 8;
        image = ".microvms/microvm-bash_history.ext4";
      }
    ];
    socket = ".microvms/microvm-control.socket";
    interfaces = [
      {
        type = "user";
        id = "vm-enp0s5";
        mac = "00:00:01:00:00:01";
      }
    ];
  };

  system.switch.enable = true;

  networking.hostName = "microvm";
  system.stateVersion = "26.05";
  time.timeZone = "America/Chicago";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  users.mutableUsers = false;
  users.users.root.password = "";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };
  environment.systemPackages = with pkgs; [
    yq-go
    ripgrep
    kubectl
    nfs-utils
    openiscsi
    nerdctl
    k9s
    go
  ];
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  services.openiscsi = {
    enable = true;
    name = "microvm-initiatorhost";
  };

  services.k3s.enable = true;

  systemd.services.build-and-push-patch-longhorn =
    let
      version = "0.1.0";

      patch-longhorn-manager-adm-ctl-binary = pkgs.buildGoModule {
        pname = "patch-longhorn-manager-adm-ctl";
        version = version;
        src = ./src;
        vendorHash = "sha256-qVSUymTDYc2caXEUW6jmJ8July11xLuvmYGndjBpk58=";
        ldflags = [
          "-s"
          "-w"
        ];
        env.CGO_ENABLED = "0";
      };

      patch-longhorn-manager-adm-ctl-image = pkgs.dockerTools.buildImage {
        name = "${config.networking.hostName}/patch-longhorn-manager-adm-ctl";
        tag = version;
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [
            patch-longhorn-manager-adm-ctl-binary
            (pkgs.runCommand "tls-certs" { } ''
              mkdir -p $out/etc/tls
              cp ${./chart/files/default.crt} $out/etc/tls/tlcrt
              cp ${./chart/files/default.key} $out/etc/tls/tlkey
            '')
          ];
          pathsToLink = [
            "/bin"
            "/etc"
          ];
        };
        config.Entrypoint = [
          "${patch-longhorn-manager-adm-ctl-binary}/bin/patch-longhorn-manager-adm-ctl"
        ];
      };
    in
    {
      description = "Load patch-longhorn-manager-adm-ctl image to containerd";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "k3s.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "load-image" ''
          set -euo pipefail
          ${pkgs.k3s}/bin/k3s ctr images import ${patch-longhorn-manager-adm-ctl-image}
        '';
      };
    };
}
