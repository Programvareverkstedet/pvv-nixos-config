{ ... }:
{
  services.nginx.virtualHosts."www.pvv.ntnu.no".locations = {
    "^~ /.well-known/" = {
      alias = (toString ./root) + "/";
    };

    # Proxy the matrix well-known files
    # Host has be set before proxy_pass
    # The header must be set so nginx on the other side routes it to the right place
    "^~ /.well-known/matrix/" = {
      extraConfig = ''
        proxy_set_header Host matrix.pvv.ntnu.no;
        proxy_pass https://matrix.pvv.ntnu.no/.well-known/matrix/;
      '';
    };
  };
}
