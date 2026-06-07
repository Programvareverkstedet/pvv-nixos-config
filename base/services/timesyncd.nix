{ ... }:
{
  services.timesyncd = {
    servers = [ "ntp.ntnu.no" ];
    fallbackServers = [
      "0.pool.ntp.org"
      "1.pool.ntp.org"
      "0.no.pool.ntp.org"
    ];
  };
}

