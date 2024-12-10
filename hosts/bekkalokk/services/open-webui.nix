{ config, pkgs, lib, ... }:
let
  cfg = config.services.open-webui;
  domain = "gpt.pvv.ntnu.no";
  address = "127.0.1.11";
  port = 11111;

in
{

  services.open-webui = {
    enable = true;

    package = pkgs.unstable.open-webui;
    port = port;
    host = "${address}";
    openFirewall = true;
	
	environment = {
  		ANONYMIZED_TELEMETRY = "False";
  		DO_NOT_TRACK = "True";
  		SCARF_NO_ANALYTICS = "True";
		OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
		ENABLE_SIGNUP = "False";
		ENABLE_OAUTH_SIGNUP = "True";
		#ENABLE_LOGIN_FORM = "False"; #for forcing oauth only - less confusion but needed for local admin account i think
		DEFAULT_USER_ROLE = "user";
		ENABLE_ADMIN_EXPORT = "False";
		ENABLE_ADMIN_CHAT_ACCESS = "False";
		ENABLE_COMMUNITY_SHARING = "False";
		WEBUI_URL = "${domain}";
	};

  };
  
  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;

    locations."/" = {
      proxyPass = "http://${address}:${toString port}";
      proxyWebsockets = true;
    };
  };

  
  
}