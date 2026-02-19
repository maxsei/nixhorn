{ pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/minimal.nix") ];

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
    ripgrep
  ];
}
