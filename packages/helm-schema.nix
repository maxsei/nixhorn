{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "helm-schema";
  version = "0.21.2";

  src = fetchFromGitHub {
    owner = "dadav";
    repo = "helm-schema";
    rev = version;
    hash = "sha256-nN+i0HrgybS/fyhyEaAb/VH24noyV7dE4svrEhH8cs8=";
  };

  vendorHash = "sha256-JV9/za2NeRmWTLrP9Urr5Ak/Am85uFTq+hFgTurtPUU=";

  subPackages = [ "cmd/helm-schema" ];
}
