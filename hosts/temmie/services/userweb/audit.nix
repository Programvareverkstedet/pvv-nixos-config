{ config, lib, ... }:
let
  cfg = config.services.httpd;
  uid = toString config.users.users.${cfg.user}.uid;
in
{
  security.audit.rules = lib.mkIf (cfg.enable && config.security.auditd.enable) ((map
    # catch AF_INET/6 `bind()` by wwwrun, indicates someone might be trying hacc.
    (fam: "-a always,exit -F arch=b64 -S bind -F uid=${uid} -F saddr_fam=${toString fam} -k userweb-bind")
    [
      2 # AF_INET
      10 # AF_INET6
    ]
  ) ++ [
    # `listen()` is also sussy amogus
    "-a always,exit -F arch=b64 -S listen -F uid=${uid} -k userweb-bind"
  ]);
}
