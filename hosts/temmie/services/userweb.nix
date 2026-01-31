{ config, lib, pkgs, ... }:
let
  cfg = config.services.httpd;

  homeLetters = [ "a" "b" "c" "d" "h" "i" "j" "k" "l" "m" "z" ];

  # https://nixos.org/manual/nixpkgs/stable/#ssec-php-user-guide-installing-with-extensions
  phpEnv = pkgs.php.buildEnv {
    extensions = { all, ... }: with all; [
      imagick
      opcache
      protobuf
    ];

    extraConfig = ''
      display_errors=0
      post_max_size = 40M
      upload_max_filesize = 40M
    '';
  };

  perlEnv = pkgs.perl.withPackages (ps: with ps; [
    pkgs.exiftool
    pkgs.ikiwiki
    pkgs.irssi
    pkgs.nix.libs.nix-perl-bindings

    AlgorithmDiff
    AnyEvent
    AnyEventI3
    ArchiveZip
    CGI
    CPAN
    CPANPLUS
    DBDPg
    DBDSQLite
    DBI
    EmailAddress
    EmailSimple
    Env
    Git
    HTMLMason
    HTMLParser
    HTMLTagset
    HTTPDAV
    HTTPDaemon
    ImageMagick
    JSON
    LWP
    MozillaCA
    PathTiny
    Switch
    SysSyslog
    TestPostgreSQL
    TextPDF
    TieFile
    Tk
    URI
    XMLLibXML
  ]);

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
    paths = with pkgs; [
      bash

      perlEnv
      pythonEnv

      phpEnv
    ]
    ++ (with phpEnv.packages; [
      # composer
    ])
    ++ [
      acl
      aspell
      autoconf
      autotrash
      bazel
      bintools
      bison
      bsd-finger
      catdoc
      ccache
      clang
      cmake
      coreutils-full
      curl
      devcontainer
      diffutils
      emacs
      # exiftags
      exiftool
      ffmpeg
      file
      findutils
      gawk
      gcc
      glibc
      gnugrep
      gnumake
      gnupg
      gnuplot
      gnused
      gnutar
      gzip
      html-tidy
      imagemagick
      inetutils
      iproute2
      jhead
      less
      libgcc
      lndir
      mailutils
      man # TODO: does this one want a mandb instance?
      meson
      more
      mpc
      mpi
      mplayer
      ninja
      nix
      openssh
      openssl
      patchelf
      pkg-config
      ppp
      procmail
      procps
      qemu
      rc
      rhash
      rsync
      ruby # TODO: does this one want systemwide packages?
      salt
      sccache
      sourceHighlight
      spamassassin
      strace
      subversion
      system-sendmail
      systemdMinimal
      texliveMedium
      tmux
      unzip
      util-linux
      valgrind
      vim
      wget
      which
      wine
      xdg-utils
      zip
      zstd
    ];

    extraOutputsToInstall = [
      "man"
      "doc"
    ];
  };
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
    phpPackage = phpEnv;

    enablePerl = true;

    # TODO: mod_log_journald in v2.5
    extraModules = [
      "systemd"
      "userdir"
      # TODO: I think the compilation steps of pkgs.apacheHttpdPackages.mod_perl might have some
      #       incorrect or restrictive assumptions upstream, either nixpkgs or source
      # {
      #   name = "perl";
      #   path = let
      #     mod_perl = pkgs.apacheHttpdPackages.mod_perl.override {
      #       apacheHttpd = cfg.package.out;
      #       perl = perlEnv;
      #     };
      #   in "${mod_perl}/modules/mod_perl.so";
      # }
    ];

    extraConfig = ''
      TraceEnable on
      LogLevel warn rewrite:trace3
      ScriptLog ${cfg.logDir}/cgi.log
    '';

    # virtualHosts."userweb.pvv.ntnu.no" = {
    virtualHosts."temmie.pvv.ntnu.no" = {
      forceSSL = true;
      enableACME = true;

      extraConfig = ''
        UserDir ${lib.concatMapStringsSep " " (l: "/home/pvv/${l}/*/web-docs") homeLetters}
        UserDir disabled root
        AddHandler cgi-script .cgi
        DirectoryIndex index.html index.html.var index.php index.php3 index.cgi index.phtml index.shtml meg.html

        <Directory "/home/pvv/?/*/web-docs">
          Options MultiViews Indexes SymLinksIfOwnerMatch ExecCGI IncludesNoExec
          AllowOverride All
          Require all granted
        </Directory>
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

  systemd.services.httpd = {
    after = [ "pvv-homedirs.target" ];
    requires = [ "pvv-homedirs.target" ];

    environment = {
      PATH = lib.mkForce "/usr/bin";
    };

    serviceConfig = {
      Type = lib.mkForce "notify";

      ExecStart = lib.mkForce "${cfg.package}/bin/httpd -D FOREGROUND -f /etc/httpd/httpd.conf -k start";
      ExecReload = lib.mkForce "${cfg.package}/bin/httpd -f /etc/httpd/httpd.conf -k graceful";
      ExecStop = lib.mkForce "";
      KillMode = "mixed";

      ConfigurationDirectory = [ "httpd" ];
      LogsDirectory = [ "httpd" ];
      LogsDirectoryMode = "0700";

      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      LockPersonality = true;
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
      SystemCallFilter = [
         "@system-service"
      ];
      UMask = "0077";

      RuntimeDirectory = [ "httpd/root-mnt" ];
      RootDirectory = "/run/httpd/root-mnt";
      MountAPIVFS = true;
      BindReadOnlyPaths = [
        builtins.storeDir
        "/etc"
        # NCSD socket
        "/var/run"
        "/var/lib/acme"

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
