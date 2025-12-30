{ config, pkgs, lib, values, ... }:
let
  inherit (config.lib.topology) mkDevice;
in {
  nodes.balduzius = mkDevice "balduzius" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    interfaceGroups = [ [ "ens18" ] ];
    interfaces.ens18 = {
      mac = "00:0c:29:de:05:0f";
      addresses = [
        "129.241.210.192"
        "2001:700:300:1900::1:42"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };

    services = {
      kdc = {
        name = "Heimdal KDC";
        info = "kdc.pvv.ntnu.no";
        details.kdc.text = "0.0.0.0:88";
        details.kpasswd.text = "0.0.0.0:464";
      };
    };
  };
  nodes.tom = mkDevice "tom" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    interfaceGroups = [ [ "ens18" ] ];
    interfaces.ens18 = {
      mac = "00:0c:29:4d:f7:56";
      addresses = [
        "129.241.210.180"
        "2001:700:300:1900::180"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };

    services = {
      apache2 = {
        name = "Apache2 - user websites";
        info = "www.pvv.ntnu.no/~";
        details.listen.text = "0.0.0.0:443";
      };
    };
  };
  nodes.hildring = mkDevice "hildring" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
    deviceType = "loginbox";
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    interfaceGroups = [ [ "eth0" ] ];
    interfaces.eth0 = {
      mac = "00:0c:29:e7:dd:79";
      addresses = [
        "129.241.210.176"
        "2001:700:300:1900::1:9"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };
  nodes.drolsum = mkDevice "drolsum" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
    deviceType = "loginbox";
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";
  };

  nodes.microbel = mkDevice "microbel" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    hardware.info = "Supermicro X8ST3";

    interfaceGroups = [ [ "eth0" "eth1" ] ];
    interfaces.eth0 = {
      mac = "00:25:90:24:76:2c";
      addresses = [
        "129.241.210.179"
        "2001:700:300:1900::1:2"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };
  nodes.innovation = mkDevice "innovation" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/freebsd.svg";

    hardware.info = "Dell Optiplex 9010";

    interfaceGroups = [ [ "em0" ] ];
    interfaces.em0 = {
      mac = "18:03:73:20:18:d3";
      addresses = [
        "129.241.210.214"
        "2001:700:300:1900::1:56"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
    services = {
      minecraft = {
        name = "Minecraft";
        icon = "services.minecraft";
        info = "minecraft.pvv.ntnu.no";
        details.listen.text = "0.0.0.0:25565";
      };
    };
  };
  nodes.principal = mkDevice "principal" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/freebsd.svg";

    interfaceGroups = [ [ ] ];
  };
  nodes.sleipner = mkDevice "sleipner" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    interfaceGroups = [ [ "eno0" "enp2s0" ] ];
    interfaces.enp2s0 = {
      mac = "00:25:90:57:35:8e";
      addresses = [
        "129.241.210.193"
        "2001:700:300:1900:fab:cab:dab:7ab"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };
  nodes.isvegg = mkDevice "isvegg" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    interfaceGroups = [ [ ] ];
  };
  nodes.ameno = mkDevice "ameno" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/ubuntu.svg";

    interfaceGroups = [ [ "eth0" ] ];
    interfaces.eth0 = {
      mac = "b8:27:eb:62:1d:d8";
      addresses = [
        "129.241.210.230"
        "129.241.210.211"
        "129.241.210.153"
        "2001:700:300:1900:ba27:ebff:fe62:1dd8"
        "2001:700:300:1900::4:230"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
    services = {
      bind = {
        name = "Bind DNS";
        icon = ./icons/bind9.png;
        info = "hostmaster.pvv.ntnu.no";
        details.listen.text = "0.0.0.0:53";
      };
    };
  };
  nodes.skrott = mkDevice "skrott" {
    interfaceGroups = [ [ ] ];
  };
  nodes.torskas = mkDevice "torskas" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/arch_linux.svg";

    interfaceGroups = [ [ ] ];
  };
  nodes.wegonke = mkDevice "wegonke" {
    deviceType = "terminal";
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    hardware.info = "ASUSTeK G11CD-K";

    interfaceGroups = [ [ "enp4s0" ] ];
    interfaces.enp4s0 = {
      mac = "70:4d:7b:a3:32:57";
      addresses = [
        "129.241.210.218"
        "2001:700:300:1900::1:218"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };
  nodes.demiurgen = mkDevice "demiurgen" {
    deviceType = "terminal";
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/debian.svg";

    interfaceGroups = [ [ "eno1" ] ];
    interfaces.eno1 = {
      mac = "18:03:73:1f:f4:1f";
      addresses = [
        "129.241.210.201"
        "2001:700:300:1900::1:4e"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };

  nodes.sanctuary = mkDevice "sanctuary" {
    deviceType = "terminal";
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/windows.svg";

    interfaceGroups = [ [ "ethernet_0" ] ];
    interfaces.ethernet_0 = {
      addresses = [
        "129.241.210.170"
        "2001:700:300:1900::1337"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };
}
