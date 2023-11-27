{ config, lib, ... }:
{
  services.nginx.virtualHosts = {
    "www2.pvv.ntnu.no" = {
      serverAliases = [ "www2.pvv.org" "pvv.ntnu.no" "pvv.org" ];
      addSSL = true;
      enableACME = true;

      locations = {
        # Proxy home directories
        "/~" = {
          extraConfig = ''
            proxy_redirect off;
            proxy_pass https://tom.pvv.ntnu.no;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        # Redirect old wiki entries
        "/disk".return = "301 https://www.pvv.ntnu.no/pvv/Diskkjøp";
        "/dok/boker.php".return = "301 https://www.pvv.ntnu.no/pvv/Bokhyllen";
        "/styret/lover/".return = "301 https://www.pvv.ntnu.no/pvv/Lover";
        "/styret/".return = "301 https://www.pvv.ntnu.no/pvv/Styret";
        "/info/".return = "301 https://www.pvv.ntnu.no/pvv/";
        "/info/maskinpark/".return = "301 https://www.pvv.ntnu.no/pvv/Maskiner";
        "/medlemssider/meldinn.php".return = "301 https://www.pvv.ntnu.no/pvv/Medlemskontingent";
        "/diverse/medlems-sider.php".return = "301 https://www.pvv.ntnu.no/pvv/Medlemssider";
        "/cert/".return = "301 https://www.pvv.ntnu.no/pvv/CERT";
        "/drift".return = "301 https://www.pvv.ntnu.no/pvv/Drift";
        "/diverse/abuse.php".return = "301 https://www.pvv.ntnu.no/pvv/CERT/Abuse";
        "/nerds/".return = "301 https://www.pvv.ntnu.no/pvv/Nerdepizza";

        # TODO: Redirect webmail
        "/webmail".return = "301 https://webmail.pvv.ntnu.no/squirrelmail";

        # Redirect everything else to the main website
        "/".return = "301 https://www.pvv.ntnu.no$request_uri";
      };
    };
  };
}

