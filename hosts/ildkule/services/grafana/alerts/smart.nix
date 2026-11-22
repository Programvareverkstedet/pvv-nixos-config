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

      # TODO: we're missing a lot here: https://git.pvv.ntnu.no/Drift/issues/issues/692
    ])
  ];
}
