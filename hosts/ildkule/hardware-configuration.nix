{ modulesPath, lib, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e35eb4ce-aac3-4f91-8383-6e7cd8bbf942";
    fsType = "ext4";
  };
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/0a4c1234-02d3-4b53-aeca-d95c4c8d534b";
    fsType = "ext4";
  };

  networking.useDHCP = lib.mkDefault true;
}
