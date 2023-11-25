{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.services.roundcube;
  domain = "roundcube.pvv.ntnu.no";
in 
{
  services.roundcube = {
      enable = true;
      package = pkgs.roundcube.withPlugins (plugins: [ plugins.persistent_login plugins.thunderbird_labels plugins.contextmenu plugins.custom_from]);
      dicts = with pkgs.aspellDicts; [ en en-science en-computers nb  nn fr de it];
      maxAttachmentSize = 20;
      # this is the url of the vhost, not necessarily the same as the fqdn of the mailserver
      hostName = domain;

      extraConfig = ''
        # starttls needed for authentication, so the fqdn required to match
        # the certificate
        $config['enable_installer'] = false;
        $config['default_host'] = "ssl://imap.pvv.ntnu.no";
        $config['default_port'] = 993;
        #$config['smtp_server'] = "tls://smtp.pvv.ntnu.no";
        #$config['smtp_port'] = 25;
        $config['smtp_server'] = "ssl://smtp.pvv.ntnu.no";
        $config['smtp_port'] = 465;
        # $config['smtp_user'] = "%u@pvv.ntnu.no";
        $config['mail_domain'] = "pvv.ntnu.no";
        $config['smtp_user'] = "%u";
        # $config['smtp_pass'] = "%p";
        $config['support_url'] = "";
      '';
  };  
}
