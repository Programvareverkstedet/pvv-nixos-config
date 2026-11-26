{ config, lib, ... }: let
  cfg = config.services.prometheus;

  machines = let
    mkNixos = machine: { nixos = true; os = "Linux"; } // machine;
  in lib.mapAttrs
    (name: machine: {
      nixos = false;
      # NOTE: VMs don't run smartctl-exporter
      smartctl = false;
      address = "${name}.pvv.ntnu.no";
    } // machine)
    {
      bekkalokk = mkNixos { smartctl = true; };
      bicep = mkNixos { smartctl = true; };
      brzeczyszczykiewicz = mkNixos { smartctl = true; };
      demiurgen.os = "Linux";
      georg = mkNixos { smartctl = true; };
      gluttony = mkNixos { };
      ildkule = mkNixos { };
      innovation = { os = "FreeBSD"; smartctl = true; };
      isvegg.os = "Linux";
      knutsen = { os = "FreeBSD"; smartctl = true; };
      kommode = mkNixos { };
      ludvigsen = { os = "FreeBSD"; smartctl = true; address = "ludvigsen-tap.pvv.ntnu.no"; };
      lupine-1 = mkNixos { smartctl = true; };
      lupine-2 = mkNixos { smartctl = true; };
      lupine-3 = mkNixos { smartctl = true; };
      lupine-4 = mkNixos { smartctl = true; };
      lupine-5 = mkNixos { smartctl = true; };
      microbel.os = "Linux";
      mirage.os = "Linux";
      orchid.os = "Linux";
      skrot = mkNixos { smartctl = true; };
      smask.os = "OpenBSD";
      sunset.os = "Linux";
      temmie = mkNixos { };
      wegonke.os = "Linux";
      wenche = mkNixos { };
    };

  mkStaticConfigs = port: pred: lib.pipe machines [
    (lib.filterAttrs (_: pred))
    (lib.mapAttrsToList (name: machine: {
      labels = {
        hostname = name;
        inherit (machine) os;
      };
      targets = [ "${machine.address}:${toString port}" ];
    }))
  ];
in {
  services.prometheus.scrapeConfigs = [
    {
      job_name = "nixos-node";
      scheme = "https";
      metrics_path = "/prometheus-node-exporter/metrics";
      static_configs = mkStaticConfigs 443 (machine: machine.nixos);
    }
    {
      job_name = "nixos-systemd";
      scheme = "https";
      metrics_path = "/prometheus-systemd-exporter/metrics";
      static_configs = mkStaticConfigs 443 (machine: machine.nixos);
    }
    {
      job_name = "nixos-smartctl";
      scheme = "https";
      metrics_path = "/prometheus-smartctl-exporter/metrics";
      static_configs = mkStaticConfigs 443 (machine: machine.nixos && machine.smartctl);
    }
    {
      job_name = "nixos-flake-input";
      scheme = "https";
      metrics_path = "/prometheus-nixos-flake-input-exporter/metrics";
      static_configs = mkStaticConfigs 443 (machine: machine.nixos);
    }
    {
      job_name = "nixos-fluent-bit";
      scheme = "https";
      metrics_path = "/prometheus-fluent-bit-exporter/metrics";
      static_configs = mkStaticConfigs 443 (machine: machine.nixos);
    }
    {
      job_name = "non-nixos-node";
      scheme = "http";
      metrics_path = "/metrics";
      static_configs = mkStaticConfigs 9100 (machine: !machine.nixos);
    }
    {
      job_name = "non-nixos-smartctl";
      scheme = "http";
      metrics_path = "/metrics";
      static_configs = mkStaticConfigs 9633 (machine: !machine.nixos && machine.smartctl);
    }
  ];
}
