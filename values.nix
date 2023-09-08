# Feel free to change the structure of this file
let
  pvv-ipv4 = suffix: "129.241.210.${toString suffix}";
  pvv-ipv6 = suffix: "2001:700:300:1900::${toString suffix}";
in rec {
  ipv4-space = pvv-ipv4 "128/25";
  ipv6-space = pvv-ipv4 "/64";

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
    bekkalokk = {
      ipv4 = pvv-ipv4 168;
      ipv6 = pvv-ipv6 168;
    };
    ildkule = {
      ipv4 = pvv-ipv4 187;
      ipv6 = pvv-ipv6 "1:187";
    };
    bicep = {
      ipv4 = pvv-ipv4 209;
      ipv6 = pvv-ipv6 209;
    };
    shark = {
      ipv4 = pvv-ipv4 196;
      ipv6 = pvv-ipv6 196;
    };
  };

  defaultNetworkConfig = {
    networkConfig.IPv6AcceptRA = "no";
    gateway = [ hosts.gateway ];
    dns = [ "129.241.0.200" "129.241.0.201" ];
    domains = [ "pvv.ntnu.no" "pvv.org" ];
    DHCP = "no";
  };

}
