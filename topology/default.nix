{ config, pkgs, lib, values, ... }:
let
  inherit
    (config.lib.topology)
    mkInternet
    mkRouter
    mkSwitch
    mkDevice
    mkConnection
    mkConnectionRev;
in {
  imports = [
    ./non-nixos-machines.nix
  ];

  ### Networks

  networks.pvv = {
    name = "PVV Network";
    cidrv4 = values.ipv4-space;
    cidrv6 = values.ipv6-space;
  };

  networks.site-vpn = {
    name = "OpenVPN Site to Site";
    style = {
      primaryColor = "#9dd68d";
      secondaryColor = null;
      pattern = "dashed";
    };
  };

  networks.ntnu = {
    name = "NTNU";
    cidrv4 = values.ntnu.ipv4-space;
    cidrv6 = values.ntnu.ipv6-space;
  };

  nodes.internet = mkInternet {
    connections = mkConnection "ntnu" "wan1";
  };

  nodes.ntnu = mkRouter "NTNU" {
    interfaceGroups = [ ["wan1"] ["eth1" "eth2" "eth3"] ];
    connections.eth1 = mkConnection "ntnu-pvv-router" "wan1";
    connections.eth2 = mkConnection "ntnu-veggen" "wan1";
    connections.eth3 = mkConnection "stackit" "*";
    interfaces.eth1.network = "ntnu";
  };

  ### Brus

  nodes.ntnu-pvv-router = mkRouter "NTNU PVV Gateway" {
    interfaceGroups = [ ["wan1"] ["eth1"] ];
    connections.eth1 = mkConnection "knutsen" "em1";
    interfaces.eth1.network = "ntnu";
  };

  nodes.knutsen = mkRouter "knutsen" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/freebsd.svg";

    interfaceGroups = [ ["em0"] ["em1"] ["vpn1"] ];

    connections.em0 = mkConnection "nintendo" "eth0";

    # connections.vpn1 = mkConnection "ludvigsen" "vpn1";
    interfaces.vpn1.network = "site-vpn";
    interfaces.vpn1.virtual = true;
    interfaces.vpn1.icon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/openvpn.svg";

    interfaces.em0.network = "pvv";
    interfaces.em1.network = "ntnu";
  };

  nodes.nintendo = mkSwitch "Nintendo (brus switch)" {
    interfaceGroups =  [ (lib.genList (i: "eth${toString i}") 16) ];

    connections = let
      connections' = [
        (mkConnection "bekkalokk" "enp2s0")
        # (mkConnection "bicep" "enp6s0f0") # NOTE: physical machine is dead at the moment
        (mkConnection "buskerud" "eth1")
        # (mkConnection "knutsen" "eth1")
        (mkConnection "powerpuff-cluster" "eth1")
        (mkConnection "powerpuff-cluster" "eth2")
        (mkConnection "powerpuff-cluster" "eth3")
        (mkConnection "lupine-1" "enp0s31f6")
        (mkConnection "lupine-2" "enp0s31f6")
        (mkConnection "lupine-3" "enp0s31f6")
        (mkConnection "lupine-4" "enp0s31f6")
        (mkConnection "lupine-5" "enp0s31f6")
        (mkConnection "innovation" "em0")
        (mkConnection "microbel" "eth0")
        (mkConnection "isvegg" "eth0")
        (mkConnection "ameno" "eth0")
        (mkConnection "sleipner" "eno0")
      ];
    in
    assert (lib.length connections' <= 15);
    builtins.listToAttrs (
      lib.zipListsWith
        (a: b: lib.nameValuePair a b)
        (lib.genList (i: "eth${toString (i + 1)}") 15)
        connections'
    );
  };

  nodes.bekkalokk.hardware.info = "Supermicro X9SCL/X9SCM";

  nodes.lupine-1.hardware.info = "Dell OptiPlex 7040";
  # nodes.lupine-2.hardware.info = "Dell OptiPlex 5050";
  nodes.lupine-3.hardware.info = "Dell OptiPlex 5050";
  nodes.lupine-4.hardware.info = "Dell OptiPlex 5050";
  # nodes.lupine-5.hardware.info = "Dell OptiPlex 5050";

  nodes.buskerud = mkDevice "buskerud" {
    deviceIcon = ./icons/proxmox.svg;
    interfaceGroups = [ [ "eth1" ] ];

    interfaces.eth1.network = "pvv";

    services = {
      proxmox = {
        name = "Proxmox web interface";
        info = "https://buskerud.pvv.ntnu.no:8006/";
      };
    };
  };

  nodes.shark = {
    guestType = "proxmox";
    parent = config.nodes.buskerud.id;

    interfaces.ens18.network = "pvv";
  };

  ### Powerpuff

  nodes.powerpuff-cluster = mkDevice "Powerpuff Cluster" {
    deviceIcon = ./icons/proxmox.svg;

    hardware.info = "Dell PowerEdge R730 x 3";

    interfaceGroups = [ [ "eth1" "eth2" "eth3" ] ];

    services = {
      proxmox = {
        name = "Proxmox web interface";
        details.bubbles.text = "https://bubbles.pvv.ntnu.no:8006/";
        details.blossom.text = "https://blossom.pvv.ntnu.no:8006/";
        details.buttercup.text = "https://buttercup.pvv.ntnu.no:8006/";
      };
    };
  };

  nodes.kommode = {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;

    interfaces.ens18.network = "pvv";
  };

  nodes.bicep = {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;

    # hardware.info = "HP Proliant DL370G6";

    interfaces.ens18.network = "pvv";
  };

  nodes.temmie = {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;

    interfaces.ens18.network = "pvv";
  };

  nodes.ustetind = {
    guestType = "proxmox LXC";
    parent = config.nodes.powerpuff-cluster.id;

    # TODO: the interface name is likely wrong
    # interfaceGroups = [ [ "eth0" ] ];
    interfaces.eth0 = {
      network = "pvv";
      # mac = "";
      addresses = [
        "129.241.210.234"
        "2001:700:300:1900::234"
      ];
      gateways = [
        values.hosts.gateway
        values.hosts.gateway6
      ];
    };
  };

  ### PVV

  nodes.ntnu-veggen = mkRouter "NTNU-Veggen" {
    interfaceGroups = [ ["wan1"] ["eth1"] ];
    connections.eth1 = mkConnection "ludvigsen" "re0";
  };

  nodes.ludvigsen = mkRouter "ludvigsen" {
    deviceIcon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/freebsd.svg";

    interfaceGroups = [ [ "re0" ] [ "em0" ] [ "vpn1" ] ];

    connections.em0 = mkConnection "pvv-switch" "eth0";

    interfaces.vpn1.network = "site-vpn";
    interfaces.vpn1.virtual = true;
    interfaces.vpn1.icon = "${pkgs.super-tiny-icons}/share/icons/SuperTinyIcons/svg/openvpn.svg";

    interfaces.re0.network = "ntnu";
    interfaces.em0.network = "pvv";
  };

  nodes.pvv-switch = mkSwitch "PVV Switch (Terminalrommet)" {
    interfaceGroups =  [ (lib.genList (i: "eth${toString i}") 16) ];
    connections = let
      connections' = [
        (mkConnection "brzeczyszczykiewicz" "eno1")
        (mkConnection "georg" "eno1")
        (mkConnection "wegonke" "enp4s0")
        (mkConnection "demiurgen" "eno1")
        (mkConnection "sanctuary" "ethernet_0")
        (mkConnection "torskas" "eth0")
        (mkConnection "skrott" "eth0")
        (mkConnection "homeassistant" "eth0")
        (mkConnection "orchid" "eth0")
        (mkConnection "principal" "em0")
      ];
    in
    assert (lib.length connections' <= 15);
    builtins.listToAttrs (
      lib.zipListsWith
        (a: b: lib.nameValuePair a b)
        (lib.genList (i: "eth${toString (i + 1)}") 15)
        connections'
    );
  };


  ### Openstack

  nodes.stackit = mkDevice "stackit" {
    interfaceGroups = [ [ "*" ] ];

    interfaces."*".network = "ntnu";
  };

  nodes.ildkule = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;

    interfaces.ens4.network = "ntnu";
  };
  nodes.gluttony = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;

    interfaces.ens3.network = "ntnu";
  };
  nodes.wenche = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;

    interfaces.ens18.network = "pvv";
  };
  nodes.bakke = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;

    interfaces.enp2s0.network = "pvv";
  };
}
