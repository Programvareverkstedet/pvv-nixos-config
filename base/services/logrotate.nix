{ pkgs, ... }:
{
  services.logrotate.settings.header = {
    compress = true;
    compresscmd = "${pkgs.zstd}/bin/zstd";
    compressoptions = "-T0 --rm -q";
    uncompresscmd = "${pkgs.zstd}/bin/unzstd";
    compressext = ".zst";
  };

  systemd.services.logrotate = {
    documentation = [ "man:logrotate(8)" "man:logrotate.conf(5)" ];
    unitConfig.RequiresMountsFor = "/var/log";
    serviceConfig.ReadWritePaths = [ "/var/log" ];
  };
}
