{ ... }:
{
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
}
