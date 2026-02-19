{ ... }:
{
  imports = [
    ./longhorn
    ./nixhorn/app.nix
  ];

  nixidy.target.rootPath = "manifests";
  nixidy.target.repository = "";
  nixidy.target.branch = "";
}
