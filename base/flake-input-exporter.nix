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
  port = 9102;
in
{
  services.nginx.virtualHosts."${config.networking.fqdn}-nixos-metrics" = {
    serverName = config.networking.fqdn;
    serverAliases = [
      "${config.networking.hostName}.pvv.org"
    ];
    locations."/metrics" = {
      root = "${folder}/share";
      tryFiles = "/flake-inputs =404";
      extraConfig = ''
        default_type text/plain;
      '';
    };
    listen = [
      {
        inherit port;
        addr = "0.0.0.0";
      }
    ];
    extraConfig = ''
      allow ${values.hosts.ildkule.ipv4}/32;
      allow ${values.hosts.ildkule.ipv6}/128;
      allow 127.0.0.1/32;
      allow ::1/128;
      allow ${values.ipv4-space};
      allow ${values.ipv6-space};
      deny all;
    '';
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
