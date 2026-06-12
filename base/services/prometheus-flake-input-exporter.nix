{
  config,
  inputs,
  lib,
  pkgs,
  values,
  ...
}:
let
  data = lib.flip lib.mapAttrs inputs (
    name: input: {
      inherit (input)
        lastModified
        ;
    }
  );
  folder = pkgs.writeTextDir "share/flake-inputs" (
    lib.concatMapStringsSep "\n" (
      { name, value }: ''nixos_last_modified_input{flake="${name}"} ${toString value.lastModified}''
    ) (lib.attrsToList data)
  );
in
{
  services.nginx = {
    enable = lib.mkDefault true;

    virtualHosts.${config.networking.fqdn} = lib.mkIf config.services.nginx.enable {
      forceSSL = true;
      enableACME = true;
      kTLS = true;

      locations."/prometheus-nixos-flake-input-exporter/metrics" = {
        root = "${folder}/share";
        tryFiles = "/flake-inputs =404";
        extraConfig = ''
          default_type text/plain;

          allow 127.0.0.1;
          allow ::1;
          allow ${values.hosts.ildkule.ipv4};
          allow ${values.hosts.ildkule.ipv6};
          deny all;
        '';
      };
    };
  };
}
