{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.services.prometheus.exporters.blackbox;

  excludedNixosHosts = [
    "bikkje"
    "shark"
  ];

  # Non-NixOS host to ping
  extraIcmpHosts = [
    "ambidextrous"
    "balduzius"
    "blossom"
    "bubbles"
    "buskerud"
    "buttercup"
    "demiurgen"
    "dvask"
    "hildring"
    "innovation"
    "isvegg"
    "kana"
    "knutsen"
    "microbel"
    "mirage"
    "orchid"
    "principal"
    "sleipner"
    "smask"
    "sunset"
    "tom"
    "wegonke"
  ];

  # These have no AAAA record
  ipv4OnlyIcmpHosts = [
    "balduzius"
    "dvask"
    "knutsen"
  ];

  extraCertTargets = {
    isvegg = [
      "isvegg.pvv.ntnu.no:443"
    ];

    microbel = [
      "mail.pvv.ntnu.no:465"
      "imap.pvv.ntnu.no:993"
      "pop.pvv.ntnu.no:995"

      # list.pvv.ntnu.no does not have a valid cert
      # "list.pvv.ntnu.no:443"
    ];
  };

  # Hosts that don't respond 200 on /
  httpsIgnoredVhosts = [
    "hookshot.pvv.ntnu.no"
  ];

  nixosHosts = removeAttrs inputs.self.nixosConfigurations excludedNixosHosts;

  hasTLS = v:
    (v.forceSSL || v.addSSL || v.onlySSL)
    && (v.enableACME || v.useACMEHost != null);

  icmpHosts = lib.attrNames nixosHosts ++ extraIcmpHosts;
  mkIcmpTargets = map (hostname: {
    target = "${hostname}.pvv.ntnu.no";
    labels = { inherit hostname; };
  });

  httpsVhosts = lib.pipe nixosHosts [
    (lib.mapAttrs (_: nixosConfig: nixosConfig.config.services.nginx.virtualHosts))
    (lib.mapAttrs (hostname: lib.mapAttrs (vhost: vhostCfg: vhostCfg // { inherit hostname vhost; })))
    (lib.mapAttrsToList (_: lib.attrValues))
    lib.concatLists
    (lib.filter hasTLS)
  ];
  httpsVhostNames = lib.pipe httpsVhosts [
    (map (v: v // { names = [ v.vhost ] ++ v.serverAliases; }))
    (lib.concatMap (v: map (name: { inherit (v) hostname vhost; inherit name; }) v.names))
  ];
  httpsTargets = lib.pipe httpsVhosts [
    (lib.filter (v: !(lib.elem v.vhost httpsIgnoredVhosts)))
    (map (v: {
      target = v.vhost;
      labels = { inherit (v) hostname vhost; };
    }))
  ];

  certificateTargets = lib.pipe httpsVhostNames [
    (map (v: {
      target = "${v.name}:443";
      labels = { inherit (v) hostname vhost; };
    }))
    (targets: targets ++
      lib.concatLists (lib.mapAttrsToList (hostname: map (target: {
        inherit target;
        labels = { inherit hostname; };
      })) extraCertTargets)
    )
  ];

  scrapingJobs = {
    icmp4 = {
      interval = "30s";
      module = {
        prober = "icmp";
        timeout = "5s";
        icmp = {
          preferred_ip_protocol = "ip4";
          ip_protocol_fallback = false;
        };
      };
      targets = mkIcmpTargets icmpHosts;
    };

    icmp6 = {
      interval = "30s";
      module = {
        prober = "icmp";
        timeout = "5s";
        icmp = {
          preferred_ip_protocol = "ip6";
          ip_protocol_fallback = false;
        };
      };
      targets = mkIcmpTargets (lib.subtractLists ipv4OnlyIcmpHosts icmpHosts);
    };

    https = {
      interval = "1m";
      targetFormat = "https://$1/";
      module = {
        prober = "http";
        timeout = "10s";
        http = {
          method = "GET";
          fail_if_not_ssl = true;
          follow_redirects = true;
        };
      };
      targets = httpsTargets;
    };

    certificate = {
      interval = "2m";
      module = {
        prober = "tcp";
        timeout = "10s";
        tcp.tls = true;
      };
      targets = certificateTargets;
    };
  };
in
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    listenAddress = "127.0.0.1";
    configFile = (pkgs.formats.yaml { }).generate "blackbox.yml" {
      modules = lib.mapAttrs (_: job: job.module) scrapingJobs;
    };
  };

  services.prometheus.scrapeConfigs = let
    scrapeCfgs = lib.mapAttrsToList (module: job: {
      job_name = "blackbox-${module}";
      scrape_interval = job.interval;
      metrics_path = "/probe";
      params.module = [ module ];
      static_configs = map (t: {
        targets = [ t.target ];
        inherit (t) labels;
      }) job.targets;
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
          replacement = job.targetFormat or "$1";
        }
        { source_labels = [ "__param_target" ]; target_label = "instance"; }
        { source_labels = [ "__param_target" ]; target_label = "target"; }
        { target_label = "__address__"; replacement = "${cfg.listenAddress}:${toString cfg.port}"; }
      ];
    }) scrapingJobs;
  in lib.mkIf cfg.enable scrapeCfgs;
}
