# Feel free to change the structure of this file
let
  pvv-ipv4 = suffix: "129.241.210.${toString suffix}";
  pvv-ipv6 = suffix: "2001:700:300:1900::${toString suffix}";
in rec {
  ipv4-space = pvv-ipv4 "128/25";
  ipv6-space = pvv-ipv6 "/64";

  services = {
    matrix = {
      inherit (hosts.bicep) ipv4 ipv6;
    };
    postgres = {
      inherit (hosts.bicep) ipv4 ipv6;
    };
    mysql = {
      inherit (hosts.bicep) ipv4 ipv6;
    };
    # Also on bicep
    turn = {
      ipv4 = pvv-ipv4 213;
      ipv6 = pvv-ipv6 213;
    };
    log-collector = {
      inherit (hosts.ildkule) ipv4 ipv6;
    };
  };

  hosts = {
    gateway = pvv-ipv4 129;
    bekkalokk = {
      ipv4 = pvv-ipv4 168;
      ipv6 = pvv-ipv6 168;
    };
    ildkule = {
      ipv4 = "10.212.25.209";
      ipv6 = "2001:700:300:6025:f816:3eff:feee:812d";

      ipv4_global = "129.241.153.213";
      ipv6_global = "2001:700:300:6026:f816:3eff:fe58:f1e8";
    };
    bicep = {
      ipv4 = pvv-ipv4 209;
      ipv6 = pvv-ipv6 209;
    };
    bob = {
      ipv4 = "129.241.152.254";
      # ipv6 = ;
    };
    knutsen = {
      ipv4 = pvv-ipv4 191;
    };
    shark = {
      ipv4 = pvv-ipv4 196;
      ipv6 = pvv-ipv6 196;
    };
    brzeczyszczykiewicz = {
      ipv4 = pvv-ipv4 205;
      ipv6 = pvv-ipv6 "1:50"; # Wtf peder why
    };
    georg = {
      ipv4 = pvv-ipv4 204;
      ipv6 = pvv-ipv6 "1:4f"; # Wtf øystein og daniel why
    };
    buskerud = {
      ipv4 = pvv-ipv4 231;
      ipv6 = pvv-ipv6 231;
    };
  };

  defaultNetworkConfig = {
    networkConfig.IPv6AcceptRA = "no";
    gateway = [ hosts.gateway ];
    dns = [ "129.241.0.200" "129.241.0.201" ];
    domains = [ "pvv.ntnu.no" "pvv.org" ];
    DHCP = "no";
  };

  openstackGlobalNetworkConfig = {
    networkConfig.IPv6AcceptRA = "yes";
    dns = [ "129.241.0.200" "129.241.0.201" ];
    domains = [ "pvv.ntnu.no" "pvv.org" ];
    DHCP = "yes";
  };

  openstackLocalNetworkConfig = {
    networkConfig.IPv6AcceptRA = "no";
    dns = [ "129.241.0.200" "129.241.0.201" ];
    domains = [ "pvv.ntnu.no" "pvv.org" ];
    DHCP = "yes";

    # Only use this network for link-local networking, not global/default routes
    dhcpV4Config.UseRoutes = "no";
    routes = [
      { routeConfig = { Destination = "10.0.0.0/8"; Gateway = "_dhcp4"; }; }
    ];

    linkConfig.RequiredForOnline = "no";
  };
}
