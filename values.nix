# Feel free to change the structure of this file
let
  ntnu-ipv4 = suffix: "129.241.${toString suffix}";
  ntnu-ipv6 = suffix: "2001:700:300:${toString suffix}";
  pvv-ipv4 = suffix: ntnu-ipv4 "210.${toString suffix}";
  pvv-ipv6 = suffix: ntnu-ipv6 "1900::${toString suffix}";
in rec {
  ntnu.ipv4-space = ntnu-ipv4 "0.0/16"; # https://ipinfo.io/ips/129.241.0.0/16
  ntnu.ipv6-space = ntnu-ipv6 ":/48"; # https://ipinfo.io/2001:700:300::

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

    bakke = {
      ipv4 = pvv-ipv4 173;
      ipv6 = pvv-ipv6 173;
    };
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
    temmie = {
      ipv4 = pvv-ipv4 167;
      ipv6 = pvv-ipv6 167;
    };
    wenche = {
      ipv4 = pvv-ipv4 240;
      ipv6 = pvv-ipv6 240;
    };
    lupine-1 = {
      ipv4 = pvv-ipv4 224;
      ipv6 = pvv-ipv6 224;
    };
    lupine-2 = {
      ipv4 = pvv-ipv4 225;
      ipv6 = pvv-ipv6 225;
    };
    lupine-3 = {
      ipv4 = pvv-ipv4 226;
      ipv6 = pvv-ipv6 226;
    };
    lupine-4 = {
      ipv4 = pvv-ipv4 227;
      ipv6 = pvv-ipv6 227;
    };
    lupine-5 = {
      ipv4 = pvv-ipv4 228;
      ipv6 = pvv-ipv6 228;
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
