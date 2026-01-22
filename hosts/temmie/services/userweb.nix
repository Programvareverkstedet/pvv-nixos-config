{ ... }:
{
  services.httpd = {
    enable = true;

    # extraModules = [];

    # virtualHosts."userweb.pvv.ntnu.no" = {
    virtualHosts."temmie.pvv.ntnu.no" = {

      forceSSL = true;
      enableACME = true;
    };
  };

  systemd.services.httpd = {
    after = [ "pvv-homedirs.target" ];
    requires = [ "pvv-homedirs.target" ];

    serviceConfig = {
      ProtectHome = "tmpfs";
      BindPaths = let
        letters = [ "a" "b" "c" "d"  "h" "i" "j" "k" "l" "m" "z" ];
      in map (l: "/run/pvv-home-mounts/${l}:/home/pvv/${l}") letters;
    };
  };

  # TODO: create phpfpm pools with php environments that contain packages similar to those present on tom
}
