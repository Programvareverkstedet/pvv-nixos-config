{ config, lib, pkgs, ... }:
let
  cfg = config.services.httpd;
  mcfg = config.services.pvv-userweb;
in
{
  services.httpd = {
    enable = true;
    adminAddr = "drift@pvv.ntnu.no";

    # TODO: consider upstreaming systemd support
    # TODO: mod_log_journald in v2.5
    package = pkgs.apacheHttpd.overrideAttrs (prev: {
      nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.pkg-config ];
      buildInputs = prev.buildInputs ++ [ pkgs.systemdLibs ];
      configureFlags = prev.configureFlags ++ [ "--enable-systemd" ];
    });

    enablePHP = true;
    phpPackage = mcfg.php.env;
    phpOptions = mcfg.php.options;

    # NOTE: we include our own `mod_perl` in `extraModules` instead.
    enablePerl = false;

    # NOTE: we include `mod_userdir` in `extraModules` and configure this in `extraConfig` ourselves.
    # enableUserDir = false;

    # TODO: mod_log_journald in v2.5
    extraModules = [
      "systemd"
      "userdir"
      {
        name = "perl";
        path = let
          mod_perl = pkgs.symlinkJoin {
            name = "userweb_modperl_with_custom_perl_env";
            ignoreCollisions = true;
            paths = [
              (pkgs.apacheHttpdPackages.mod_perl.override {
                apacheHttpd = cfg.package.out;
              })
              mcfg.perl.env
            ];
          };
        in "${mod_perl}/modules/mod_perl.so";
      }
    ];

    logPerVirtualHost = false;

    extraConfig = lib.mkIf mcfg.debugMode ''
      TraceEnable on
      LogLevel warn rewrite:trace3
    '';

    virtualHosts."temmie.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;

      serverAliases = [
        "www2.pvv.ntnu.no"
      ];

      extraConfig = ''
        <Directory "${pkgs.emptyDirectory}">
          Require all denied
          LogLevel authz_core:crit
        </Directory>

        CustomLog "${cfg.logDir}/access.log" combined
        CustomLog "/run/httpd-log-processor-access.fifo" combined
        ErrorLog "/run/httpd-log-processor-error.fifo"
        ScriptLog "${cfg.logDir}/cgi.log"

        UserDir ${lib.concatMapStringsSep " " (l: "/home/pvv/${l}/*/web-docs") mcfg.homeLetters}

        UserDir disabled root
        UserDir disabled pvv

        AddHandler cgi-script .cgi

        DirectoryIndex ${lib.concatStringsSep " " [
          "index.htm"
          "index.html"
          "index.html.var"

          "index.shtml"
          "index.xhtml"

          "index.php"
          "index.php3"
          "index.php4"
          "index.php5"
          "index.php7"
          "index.php8"
          "index.pht"
          "index.phtml"

          "index.cgi"
          "index.txt"

          "meg.html"
        ]}

        SetEnvIf Request_URI "^/~([^/]+)" USERDIR_USER=$1

        <Directory "/home/pvv/?/*/web-docs">
          Options MultiViews Indexes SymLinksIfOwnerMatch ExecCGI IncludesNoExec
          AllowOverride All
          Require all granted
        </Directory>

        ${lib.concatMapStringsSep "\n" (d: ''
          <DirectoryMatch "/${d}(/|$)">
            Require all denied
          </DirectoryMatch>
        '') [
          "\\.git"
          "\\.hg"
          "\\.svn"
          "\\.ssh"
          "\\.bzr"
          "\\.venv"
          "CVS"
          "RCS"

          ".*\\.bak"
          ".*\\.bak.*"
          ".*\\.bkp"
          ".*\\.bkp.*"
          ".*\\.backup"
          ".*\\.backup.*"
        ]}

        ${lib.concatMapStringsSep "\n" (d: ''
          <Files "${d}">
            Require all denied
          </Files>
        '') [
          ".env"
          ".env.*"
          ".envs"
          ".envs.*"
          ".envrc"

          "*.swp"
          "*~"

          "*.bak"
          "*.bak*"
          "*.bkp"
          "*.bkp*"
          "*.backup"
          "*.backup*"

          "*.lck"
          "*.lock"
          "LCK..*"
        ]}

        <FilesMatch ".+\.ph(p[34578]?|t|tml)$">
            SetHandler application/x-httpd-php
        </FilesMatch>
        <FilesMatch ".+\.phps$">
            SetHandler application/x-httpd-php-source
            Require all denied
        </FilesMatch>
        <FilesMatch "\.pl$">
            SetHandler modperl
            PerlResponseHandler ModPerl::Registry
            Options +ExecCGI
        </FilesMatch>
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # socket activation comes in v2.5
  # systemd.sockets.httpd = {
  #   wantedBy = [ "sockets.target" ];
  #   description = "HTTPD socket";
  #   listenStreams = [
  #     "0.0.0.0:80"
  #     "0.0.0.0:443"
  #   ];
  # };

  # NOTE: 54 -> 33, this is the UID/GID we used for www-data on tom in the past.
  #       Any files accessed by or created by httpd will do so over NFS with this
  #       UID/GID pair as its credentials.
  #       This overlaps with the hardcoded `disnix` uid in nixpkgs, but we *probably*
  #       won't be using that for the foreseeable future.
  users.users."wwwrun".uid = lib.mkForce 33;
  users.groups."wwwrun".gid = lib.mkForce 33;

  systemd.targets.userweb = {
    description = "PVV HTTPD UserWeb";
  };

  systemd.slices.system-userweb = {
    description = "PVV HTTPD UserWeb";
  };

  systemd.services.httpd = {
    after = [
      "pvv-homedirs.target"
      "httpd-log-processor@access.socket"
      "httpd-log-processor@error.socket"
    ];
    requires = [
      "pvv-homedirs.target"
      "httpd-log-processor@access.socket"
      "httpd-log-processor@error.socket"
    ];
    requiredBy = [ "userweb.target" ];

    environment = {
      PATH = lib.mkForce "/usr/bin";
    };

    serviceConfig = {
      Type = lib.mkForce "notify";
      ExecStart = lib.mkForce "${cfg.package}/bin/httpd -D FOREGROUND -f /etc/httpd/httpd.conf -k start";
      ExecReload = lib.mkForce "${cfg.package}/bin/httpd -f /etc/httpd/httpd.conf -k graceful";
      ExecStop = lib.mkForce "";
      KillMode = "mixed";
      Slice = "system-userweb.slice";

      ConfigurationDirectory = [ "httpd" ];
      LogsDirectory = [ "httpd" ];
      LogsDirectoryMode = "0700";

      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ] ++ lib.optionals mcfg.debugMode [ "CAP_SYS_PTRACE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ] ++ lib.optionals mcfg.debugMode [ "CAP_SYS_PTRACE" ];
      LockPersonality = !mcfg.debugMode;
      PrivateDevices = true;
      PrivateTmp = true;
      # NOTE: this removes CAP_NET_BIND_SERVICE...
      # PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = "tmpfs";
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectSystem = true;
      RemoveIPC = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
        "AF_NETLINK"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SocketBindDeny = "any";
      SocketBindAllow = [
        "tcp:80"
        "tcp:443"
      ];
      SystemCallArchitectures = "native";
      SystemCallFilter = lib.mkIf (!mcfg.debugMode) [ "@system-service" ];
      UMask = "0077";

      RuntimeDirectoryMode = "0750";
      RuntimeDirectory = [ "httpd/root-mnt" ];
      RootDirectory = "/run/httpd/root-mnt";
      MountAPIVFS = true;
      BindReadOnlyPaths = [
        builtins.storeDir
        "/etc"
        "/dev/null"
        "/var/lib/acme"
        "/var/run/nscd"
        "${mcfg.fhsEnv}/bin:/bin"
        "${mcfg.fhsEnv}/sbin:/sbin"
        "${mcfg.fhsEnv}/lib:/lib"
        "${mcfg.fhsEnv}/share:/share"
      ] ++ (lib.mapCartesianProduct ({ parent, child }: "${mcfg.fhsEnv}${child}:${parent}${child}") {
        parent = [
          "/local"
          "/opt"
          "/opt/local"
          "/store"
          "/store/gnu"
          "/usr"
          "/usr/local"
          "/run/current-system/sw"
        ];
        child = [
          "/bin"
          "/sbin"
          "/lib"
          "/libexec"
          "/include"
          "/share"
        ];
      });
      BindPaths = (lib.mapCartesianProduct ({ directoryFn, letter }: "/run/pvvhome/${letter}:${directoryFn letter}${letter}") {
        directoryFn = [
          (_: "/home/pvv/")
          (l: "/amd/homepvv${l}/")
        ];
        letter = mcfg.homeLetters;
      }) ++ [
        "/run/httpd-log-processor-access.fifo"
        "/run/httpd-log-processor-error.fifo"
      ];
    };
  };

  # TODO: create phpfpm pools with php environments that contain packages similar to those present on tom
}
