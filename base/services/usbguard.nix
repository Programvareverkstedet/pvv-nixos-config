{ lib, ... }:
{
  services.usbguard = {
    enable = lib.mkDefault true;
    implicitPolicyTarget = "allow";
    presentDevicePolicy = "allow";
    presentControllerPolicy = "allow";
    insertedDevicePolicy = "apply-policy";
  };

  systemd.services.usbguard.serviceConfig.Slice = "system-monitoring.slice";
}
