{
  config,
  pkgs,
  lib,
  ...
}:
let
  organizations = [
    "Drift"
    "Projects"
    "Grzegorz"
    "Kurs"
  ];

  giteaCfg = config.services.gitea;

  giteaWebSecretProviderScript = pkgs.writers.writePython3 "gitea-web-secret-provider" {
    libraries = with pkgs.python3Packages; [ requests ];
    flakeIgnore = [
      "E501" # Line over 80 chars lol
      "E201" # "whitespace after {"
      "E202" # "whitespace after }"
      "E251" # unexpected spaces around keyword / parameter equals
      "W391" # Newline at end of file
    ];
    makeWrapperArgs = [
      "--prefix PATH : ${(lib.makeBinPath [ pkgs.openssh ])}"
    ];
  } (builtins.readFile ./gitea-web-secret-provider.py);
in
{
  users.groups."gitea-web" = { };
  users.users."gitea-web" = {
    group = "gitea-web";
    isSystemUser = true;
    useDefaultShell = true;
  };

  sops.secrets."gitea/web-secret-provider/token" = {
    owner = "gitea-web";
    group = "gitea-web";
    restartUnits = [
      "gitea-web-secret-provider@"
    ]
    ++ (map (org: "gitea-web-secret-provider@${org}") organizations);
  };

  systemd.slices.system-giteaweb = {
    description = "Gitea web directories";
  };

  # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#Specifiers
  # %i - instance name (after the @)
  # %d - secrets directory
  systemd.services."gitea-web-secret-provider@" = {
    description = "Ensure all repos in %i has an SSH key to push web content";
    requires = [
      "gitea.service"
      "network.target"
    ];
    serviceConfig = {
      Slice = "system-giteaweb.slice";
      Type = "oneshot";
      ExecStart =
        let
          args = lib.cli.toGNUCommandLineShell { } {
            org = "%i";
            token-path = "%d/token";
            api-url = "${giteaCfg.settings.server.ROOT_URL}api/v1";
            key-dir = "/var/lib/gitea-web/keys/%i";
            authorized-keys-path = "/var/lib/gitea-web/authorized_keys.d/%i";
            rrsync-script = pkgs.writeShellScript "rrsync-chown" ''
              mkdir -p "$1"
              ${lib.getExe pkgs.rrsync} -wo "$1"
              ${pkgs.coreutils}/bin/chown -R gitea-web:gitea-web "$1"
            '';
            web-dir = "/var/lib/gitea-web/web";
          };
        in
        "${giteaWebSecretProviderScript} ${args}";

      User = "gitea-web";
      Group = "gitea-web";

      StateDirectory = "gitea-web";
      StateDirectoryMode = "0750";
      LoadCredential = [
        "token:${config.sops.secrets."gitea/web-secret-provider/token".path}"
      ];

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = true;
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
    };
  };

  systemd.timers."gitea-web-secret-provider@" = {
    description = "Ensure all repos in %i has an SSH key to push web content";
    timerConfig = {
      RandomizedDelaySec = "1h";
      Persistent = true;
      Unit = "gitea-web-secret-provider@%i.service";
      OnCalendar = "daily";
    };
  };

  systemd.targets.timers.wants = map (org: "gitea-web-secret-provider@${org}.timer") organizations;

  services.openssh.authorizedKeysFiles = map (
    org: "/var/lib/gitea-web/authorized_keys.d/${org}"
  ) organizations;

  users.users.nginx.extraGroups = [ "gitea-web" ];
  services.nginx.virtualHosts."pages.pvv.ntnu.no" = {
    kTLS = true;
    forceSSL = true;
    enableACME = true;
    root = "/var/lib/gitea-web/web";
  };
}
