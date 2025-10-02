{ pkgs, config, ... }:
{
  services.nginx = {
    enable = true;
    appendHttpConfig = ''
      error_page 500 502 503 504 /500.html;
    '';
  };
  environment.etc."nginx/html/500.html".source = ./500.html;
}
