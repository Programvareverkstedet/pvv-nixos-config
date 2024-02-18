{ config, pkgs, lib, ... }:
{
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  boot.kernelModules = [ "kvm-intel" ];

  # On a gui-enabled machine, connect with:
  # $ virt-manager --connect "qemu+ssh://buskerud/system?socket=/var/run/libvirt/libvirt-sock"
}

