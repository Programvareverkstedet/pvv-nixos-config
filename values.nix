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
  };

  hosts = {
    gateway = pvv-ipv4 129;
    gateway6 = pvv-ipv6 1;

    bekkalokk = {
      ipv4 = pvv-ipv4 168;
      ipv6 = pvv-ipv6 168;
    };
    ildkule = {
      ipv4 = "129.241.153.213";
      ipv4_internal = "192.168.12.209";
      ipv4_internal_gw = "192.168.12.1";
      ipv6 = "2001:700:300:6026:f816:3eff:fe58:f1e8";
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
    kommode = {
      ipv4 = pvv-ipv4 223;
      ipv6 = pvv-ipv6 223;
    };
    ustetind = {
      ipv4 = pvv-ipv4 234;
      ipv6 = pvv-ipv6 234;
    };
  };

  defaultNetworkConfig = {
    dns = [ "129.241.0.200" "129.241.0.201" "2001:700:300:1900::200" "2001:700:300:1900::201" ];
    domains = [ "pvv.ntnu.no" "pvv.org" ];
    gateway = [ hosts.gateway hosts.gateway6 ];

    networkConfig.IPv6AcceptRA = "no";
    DHCP = "no";
  };
}
