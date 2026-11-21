{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.services.prometheus.exporters.blackbox;

  excludedNixosHosts = [
    "bikkje"
    "shark"
  ];

  extraCertDomains = [
    "isvegg.pvv.ntnu.no"
  ];

  # Hosts that don't respond 200 on /
  httpsIgnoredVhosts = [
    "hookshot.pvv.ntnu.no"
  ];

  nixosHosts = removeAttrs inputs.self.nixosConfigurations excludedNixosHosts;

  hasTLS = v:
    (v.forceSSL || v.addSSL || v.onlySSL)
    && (v.enableACME || v.useACMEHost != null);

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
    (targets: targets ++ map (name: { target = "${name}:443"; labels = { }; }) extraCertDomains)
  ];

  scrapingJobs = {
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
        { target_label = "__address__"; replacement = "${cfg.listenAddress}:${toString cfg.port}"; }
      ];
    }) scrapingJobs;
  in lib.mkIf cfg.enable scrapeCfgs;
}
