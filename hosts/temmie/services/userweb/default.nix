{ config, lib, pkgs, ... }:
let
  cfg = config.services.httpd;

  # NOTE Enable this if you want to strace stuff in the sandbox...
  debug = false;

  homeLetters = [ "a" "b" "c" "d" "h" "i" "j" "k" "l" "m" "z" ];

  phpOptions = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${v}"){
    display_errors = "Off";
    display_startup_errors = "Off";
    post_max_size = "40M";
    upload_max_filesize = "40M";
  });

  apache-log-processor = pkgs.callPackage ./apache-log-processor { };

  # https://nixos.org/manual/nixpkgs/stable/#ssec-php-user-guide-installing-with-extensions
  phpEnv = pkgs.php.buildEnv {
    extensions = { all, ... }: with all; [
      bz2
      curl
      decimal
      gd
      imagick
      mysqli
      mysqlnd
      pgsql
      posix
      protobuf sqlite3
      uuid
      xml
      xsl
      zlib
      zstd

      pdo
      pdo_mysql
      pdo_pgsql
      pdo_sqlite
    ];

    extraConfig = phpOptions;
  };

  perlEnv = (pkgs.perl.withPackages (ps: with ps; [
    pkgs.exiftool
    pkgs.ikiwiki
    pkgs.irssi
    pkgs.nix.libs.nix-perl-bindings

    CGI
    DBDPg
    DBDSQLite
    DBDmysql
    DBI
    Git
    ImageMagick
    JSON
    TemplateToolkit
  ])).overrideAttrs (prev: {
    # NOTE: `pkgs.perl.propagatedBuildInputs` don't actually propagate through the
    #       wrapper derivation created by `withPackages`. This should compensate
    #       for that.
    postBuild = prev.postBuild + ''
      cp -r '${pkgs.perl}/nix-support' "$out"/nix-support
    '';
  });

  # https://nixos.org/manual/nixpkgs/stable/#python.buildenv-function
  pythonEnv = pkgs.python3.buildEnv.override {
    extraLibs = with pkgs.python3Packages; [
      legacy-cgi

      matplotlib
      requests
    ];
    ignoreCollisions = true;
  };

  # https://nixos.org/manual/nixpkgs/stable/#sec-building-environment
  fhsEnv = pkgs.buildEnv {
    name = "userweb-env";
    ignoreCollisions = true;
    paths = with pkgs; [
      bash

      config.services.bro.instances.userweb-sendmail.client.package

      perlEnv
      pythonEnv
      phpEnv
    ]
    ++ (with phpEnv.packages; [
      # composer
    ])
    ++ [
      # Useful packages for homepages
      exiftool
      gnuplot
      ikiwiki-full
      imagemagick
      jhead
      ruby
      sbcl
      sourceHighlight

      # Missing packages from tom
      # blosxom
      # pyblosxom
      # mediawiki (TODO: do people host their own mediawikis in userweb?)
      # nanoblogger

      # Version control
      cvs
      rcs
      git

      # Compression/Archival
      bzip2
      gnutar
      gzip
      lz4
      unzip
      xz
      zip
      zstd

      # Other tools you might expect to find on a normal system
      acl
      coreutils-full
      curl
      diffutils
      file
      findutils
      gawk
      gnugrep
      gnumake
      gnupg
      gnused
      less
      man
      util-linux
      vim
      wget
      which
      xdg-utils
    ] ++ lib.optionals debug [
      glibc.getent
      strace
      systemd
    ];

    extraOutputsToInstall = [
      "man"
      "doc"
    ];
  };
in
{
  imports = [
    ./mail.nix
  ];

  sops.secrets = {
    "httpd/passwd-ssh-key" = { };
    "httpd/ssh-known-hosts" = { };
  };

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
    phpPackage = phpEnv;
    inherit phpOptions;

    enablePerl = true;

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
              perlEnv
            ];
          };
        in "${mod_perl}/modules/mod_perl.so";
      }
    ];

    logPerVirtualHost = false;

    extraConfig = ''
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
        CustomLog "${cfg.logDir}/access.log" combined
        CustomLog "|${lib.getExe apache-log-processor} access" combined
        ErrorLog "|${lib.getExe apache-log-processor} error"
        ScriptLog "${cfg.logDir}/cgi.log"

        UserDir ${lib.concatMapStringsSep " " (l: "/home/pvv/${l}/*/web-docs") homeLetters}
        UserDir disabled root
        AddHandler cgi-script .cgi
        DirectoryIndex index.html index.html.var index.php index.php3 index.cgi index.phtml index.shtml meg.html
        SetEnvIf Request_URI "^/~([^/]+)" USERDIR_USER=$1

        <Directory "/home/pvv/?/*/web-docs">
          Options MultiViews Indexes SymLinksIfOwnerMatch ExecCGI IncludesNoExec
          AllowOverride All
          Require all granted
        </Directory>

        <DirectoryMatch "^/home/pvv/.*/web-docs/(${lib.concatStringsSep "|" [
          "\\.git"
          "\\.hg"
          "\\.svn"
          "\\.ssh"
          "\\.env"
          "\\.envrc"
          "\\.bzr"
          "\\.venv"
          "CVS"
          "RCS"
          ".*\\.swp"
          ".*\\.bak"
          ".*~"
        ]})(/|$)">
            AllowOverride All
            Require all denied
        </DirectoryMatch>
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

  systemd.services.httpd = {
    after = [ "pvv-homedirs.target" ];
    requires = [ "pvv-homedirs.target" ];

    environment = {
      PATH = lib.mkForce "/usr/bin";
    };

    serviceConfig = {
      Type = lib.mkForce "notify";

      ExecStartPre = let
        rsyncCommand = ''${lib.getExe pkgs.rsync} -e "${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=%d/ssh-known-hosts -i %d/sshkey" -avz'';
      in lib.mkForce [
        "${lib.getExe (pkgs.writeShellApplication {
          name = "http-exec-start-pre-remove-old-semaphores";
          text = ''
            # Get rid of old semaphores.  These tend to accumulate across
            # server restarts, eventually preventing it from restarting
            # successfully.
            for i in $(${pkgs.util-linux}/bin/ipcs -s | grep ' ${cfg.user} ' | cut -f2 -d ' '); do
                ${pkgs.util-linux}/bin/ipcrm -s "$i"
            done
          '';
        })}"

        "${rsyncCommand} pvv@smtp.pvv.ntnu.no:/etc/passwd /run/httpd/pamunix-in/"
        "${rsyncCommand} pvv@smtp.pvv.ntnu.no:/etc/group /run/httpd/pamunix-in/"

        (let
          args = lib.cli.toCommandLineShellGNU { } {
            passwd-file = "/run/httpd/pamunix-in/passwd";
            group-file = "/run/httpd/pamunix-in/group";
            output-dir = "/run/httpd/pamunix-out";
            shadow-file = pkgs.emptyFile;

            output-passwd = true;

            ignore-user-file = toString ./ignore_user_file.txt;
            ignore-group-file = toString ./ignore_group_file.txt;
          };
        in ''${lib.getExe pkgs.passwd2systemd-users} ${args}'')
        "${lib.getExe' pkgs.coreutils "shred"} -u /run/httpd/pamunix-in/passwd /run/httpd/pamunix-in/group"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash' /run/httpd/pamunix-out/passwd"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\wwwrun:x:54:54:Apache httpd user:/var/empty:/run/current-system/sw/bin/bash' /run/httpd/pamunix-out/passwd"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\root:x:0:' /run/httpd/pamunix-out/group"
        ":${lib.getExe pkgs.gnused} -i '$ a\\\\wwwrun:x:54:' /run/httpd/pamunix-out/group"
        "${lib.getExe' pkgs.coreutils "cat"} /run/httpd/pamunix-out/passwd"
        "+${lib.getExe' pkgs.coreutils "chown"} root:root /run/httpd/pamunix-out/passwd /run/httpd/pamunix-out/group"
        "+${lib.getExe' pkgs.coreutils "chmod"} 0644 /run/httpd/pamunix-out/passwd /run/httpd/pamunix-out/group"
        "+${lib.getExe pkgs.mount} --bind /run/httpd/pamunix-out/passwd /etc/passwd"
        "+${lib.getExe pkgs.mount} --bind /run/httpd/pamunix-out/group  /etc/group"
      ];
      ExecStart = lib.mkForce "${cfg.package}/bin/httpd -D FOREGROUND -f /etc/httpd/httpd.conf -k start";
      ExecReload = lib.mkForce "${cfg.package}/bin/httpd -f /etc/httpd/httpd.conf -k graceful";
      ExecStop = lib.mkForce "";
      KillMode = "mixed";

      LoadCredential=[
        "sshkey:${config.sops.secrets."httpd/passwd-ssh-key".path}"
        "ssh-known-hosts:${config.sops.secrets."httpd/ssh-known-hosts".path}"
      ];

      ConfigurationDirectory = [ "httpd" ];
      LogsDirectory = [ "httpd" ];
      LogsDirectoryMode = "0700";

      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_SETUID" "CAP_SETGID" ] ++ lib.optionals debug [ "CAP_SYS_PTRACE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_SETUID" "CAP_SETGID" ] ++ lib.optionals debug [ "CAP_SYS_PTRACE" ];
      LockPersonality = !debug;
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
      SystemCallFilter = lib.mkIf (!debug) [
         "@system-service"
         "@setuid"
      ];
      UMask = "0077";

      RuntimeDirectoryMode = "0750";
      RuntimeDirectory = [
        "httpd/root-mnt"
        "httpd/pamunix-in"
        "httpd/pamunix-out"
      ];
      RootDirectory = "/run/httpd/root-mnt";
      MountAPIVFS = true;
      BindReadOnlyPaths = [
        builtins.storeDir
        "/etc"
        "/dev/null"
        "/etc/resolv.conf"
        "/var/lib/acme"

        "-/run/httpd/pamunix-out/passwd:/etc/passwd"
        "-/run/httpd/pamunix-out/group:/etc/group"

        "${pkgs.writeText "userweb-fake-nsswitch.conf" ''
          passwd:    files
          group:     files
          shadow:    files
          sudoers:   files

          hosts:     mymachines resolve [!UNAVAIL=return] files myhostname dns
          networks:  files

          ethers:    files
          services:  files
          protocols: files
          rpc:       files

          subuid:    files
          subgid:    files
        ''}:/etc/nsswitch.conf"

        "${fhsEnv}/bin:/bin"
        "${fhsEnv}/sbin:/sbin"
        "${fhsEnv}/lib:/lib"
        "${fhsEnv}/share:/share"
      ] ++ (lib.mapCartesianProduct ({ parent, child }: "${fhsEnv}${child}:${parent}${child}") {
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
      BindPaths = map (l: "/run/pvv-home-mounts/${l}:/home/pvv/${l}") homeLetters;
    };
  };

  # TODO: create phpfpm pools with php environments that contain packages similar to those present on tom
}
