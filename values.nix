# Feel free to change the structure of this file
let
  pvv-ipv4 = suffix: "129.241.210.${toString suffix}";
  pvv-ipv6 = suffix: "2001:700:300:1900::${toString suffix}";
in rec {
  services = {
    matrix = {
      ipv4 = hosts.jokum.ipv4;
      ipv6 = hosts.jokum.ipv6;
    };
    # Also on jokum
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
    jokum = {
      ipv4 = pvv-ipv4 169;
      ipv6 = pvv-ipv6 169; 
    };
    ildkule = {
      ipv4 = pvv-ipv4 187;
      ipv6 = pvv-ipv6 "1:187";
    };
    bicep = {
      ipv4 = pvv-ipv4 209;
      ipv6 = pvv-ipv6 209;
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
