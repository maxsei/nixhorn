{
  lib,
  helm-schema,
  runCommand,
  writers,
  nixhorn-webhook-image,
}:
let
  chartYaml = writers.writeYAML "kustomization.yaml" {
    apiVersion = "v2";
    name = "nixhorn-webhook";
    description = "A Kubernetes admission webhook that dynamically patches Longhorn pods with NixOS-compatible PATH environment variables";
    type = "application";
    version = builtins.readFile ../VERSION;
    appVersion = nixhorn-webhook-image.imageTag;
    keywords = [
      "longhorn"
      "nixos"
      "admission-webhook"
      "mutating-webhook"
    ];
    maintainers = [ { name = "maxsei"; } ];
    home = "https://github.com/maxsei/nixhorn-webhook";
    sources = [ "https://github.com/maxsei/nixhorn-webhook" ];
  };

  valuesSchema = runCommand "nixhorn-webhook-chart-schema" { } ''
    cp ${chartYaml} Chart.yaml
    cp ${./values.yaml} values.yaml
    ${helm-schema}/bin/helm-schema
    cp ./values.schema.json $out
  '';

in
runCommand "nixhorn-webhook-chart" { } ''
  mkdir -p $out
  cp -r ${./templates} "$out/templates"
  cp -r ${./files} "$out/files"
  cp ${./values.yaml} "$out/values.yaml"
  cp ${valuesSchema} "$out/values.schema.json"
  cp ${chartYaml} "$out/Chart.yaml"
''
