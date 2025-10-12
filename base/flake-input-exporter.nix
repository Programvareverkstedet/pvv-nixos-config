{
  config,
  inputs,
  lib,
  pkgs,
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
      { name, value }:
      "nixos_last_modified_input{flake=${name},host=${config.networking.hostName}} ${toString value.lastModified}"
    ) (lib.attrsToList data)
  );
in
{
  services.nginx.virtualHosts."${config.networking.fqdn}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
    serverAliases = [
      "${config.networking.hostName}.pvv.org"
    ];
    locations."/metrics" = {
      root = "${folder}/share";
    };
    extraConfig = ''
      allow 129.241.210.128/25;
      allow 2001:700:300:1900::/64;
      deny all;
    '';
  };
}
