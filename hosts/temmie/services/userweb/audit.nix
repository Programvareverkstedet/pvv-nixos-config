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
  ] ++ map
    # catch `execve()` in dirs where haccars might try to drop some scripts.
    (dir: "-a always,exit -F arch=b64 -F dir=${dir} -F perm=x -F uid=${uid} -k userweb-exec")
    [
      "/tmp"
      "/var/tmp"
    ]
  ++ map
    # catch wwwrun trying to touch a bunch of no-no files.
    (file: "-a always,exit -F arch=b64 -F path=${file} -F perm=rwa -F uid=${uid} -k userweb-secrets")
    ([
      "/etc/shadow"
      "/etc/sudoers"
    ] ++ lib.catAttrs "path" config.services.openssh.hostKeys)
  );
}
