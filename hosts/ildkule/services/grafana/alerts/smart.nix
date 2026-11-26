{ config, lib, ... }:
let
  inherit (config.lib.grafana.alerts) mkPromAlert mkGroup;

  withDiskInfo = expr: ''
    (${expr})
      * on (hostname, device) group_left (model_name, serial_number)
      smartctl_device
  '';

  subject = "{{ $labels.device }} ({{ $labels.model_name }}, serial {{ $labels.serial_number }}) on {{ $labels.hostname }}";
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    (mkGroup "smart" [
      (mkPromAlert {
        uid = "smart-status-failing";
        title = "SMART status failing";
        expr = withDiskInfo "smartctl_device_smart_status";
        threshold = { type = "lt"; params = [ 1 ]; };
        severity = "critical";
        inherit subject;
        summary = "SMART overall-health self-assessment failed.";
      })

      (mkPromAlert {
        uid = "smart-wear-high";
        title = "SSD worn out";
        expr = withDiskInfo ''
          min by (hostname, device) (
            smartctl_device_attribute{
              attribute_value_type="value",
              attribute_name=~"${lib.concatStringsSep "|" [
                # These labels change a bit from disk to disk,
                # please add more if you see something not covered
                "Wear_Leveling_Count"
                "SSD_Life_Left"
                "Percent_Lifetime_Remain"
                "Media_Wearout_Indicator"
              ]}"
            }
          )
        '';
        threshold = { type = "lt"; params = [ 20 ]; };
        inherit subject;
        summary = "Less than 20% of endurance left.";
      })

      (mkPromAlert {
        uid = "smart-unreadable-sectors";
        title = "Disk has unreadable sectors";
        expr = withDiskInfo ''
          max by (hostname, device) (
            smartctl_device_attribute{
              attribute_value_type="raw",
              attribute_name=~"Current_Pending_Sector|Offline_Uncorrectable"
            }
          )
        '';
        threshold = { type = "gt"; params = [ 0 ]; };
        severity = "critical";
        inherit subject;
      })

      (let
        mkTemperatureAlert = { kind, rotational, limit }: mkPromAlert {
          uid = "smart-${lib.toLower kind}-temperature-high";
          title = "${kind} temperature high";
          expr = withDiskInfo ''
            smartctl_device_temperature{temperature_type="current"}
              * on (hostname, device) group_left ()
              max by (hostname, device) (node_disk_info{rotational="${toString rotational}"})
          '';
          threshold = { type = "gt"; params = [ limit ]; };
          for = "15m";
          inherit subject;
          summary = "Above ${toString limit} °C for 15 minutes.";
        };
      in [
        (mkTemperatureAlert { kind = "HDD"; rotational = 1; limit = 60; })
        (mkTemperatureAlert { kind = "SSD"; rotational = 0; limit = 70; })
      ])

      (mkPromAlert {
        uid = "smart-link-speed-degraded";
        title = "Disk link speed degraded";
        expr = withDiskInfo ''
          smartctl_device_interface_speed{speed_type="current"}
            /
          max_over_time(smartctl_device_interface_speed{speed_type="current"}[7d])
        '';
        threshold = { type = "lt"; params = [ 1 ]; };
        inherit subject;
        summary = "Link renegotiated below its speed from the last 7 days.";
      })

      # TODO: we're missing a lot here: https://git.pvv.ntnu.no/Drift/issues/issues/692
    ])
  ];
}
