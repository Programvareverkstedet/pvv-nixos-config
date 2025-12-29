{ lib, config, ... }:
let
  inherit
    (config.lib.topology)
    mkInternet
    mkRouter
    mkSwitch
    mkDevice
    mkConnection
    mkConnectionRev;
  values = import ../values.nix;
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
    connections.eth1 = mkConnection "brus-switch" "eth1";
    interfaces.eth1.network = "pvv";
  };

  nodes.brus-switch = mkSwitch "Brus Switch" {
    interfaceGroups =  [ (lib.genList (i: "eth${toString i}") 16) ];

    connections = let
      connections' = [
        (mkConnection "bekkalokk" "enp2s0")
        # (mkConnection "bicep" "enp6s0f0")
        (mkConnection "buskerud" "eth1")
        (mkConnection "knutsen" "eth1")
        (mkConnection "powerpuff-cluster" "eth1")
        (mkConnection "lupine-1" "enp0s31f6")
        (mkConnection "lupine-2" "enp0s31f6")
        (mkConnection "lupine-3" "enp0s31f6")
        (mkConnection "lupine-4" "enp0s31f6")
        (mkConnection "lupine-5" "enp0s31f6")
        (mkConnection "innovation" "em0")
        (mkConnection "microbel" "eth0")
        # (mkConnection "isvegg" "")
        # (mkConnection "ameno" "")
        # (mkConnection "sleipner" "")
      ];
    in builtins.listToAttrs (
      lib.zipListsWith
        (a: b: lib.nameValuePair a b)
        (lib.genList (i: "eth${toString i}") 16)
        connections'
    );
  };

  nodes.knutsen = mkRouter "knutsen" {
    interfaceGroups = [ ["eth1"] ["eth2"] ["vpn1"] ];
    connections.eth2 = mkConnectionRev "brus-switch" "eth6";
    # connections.vpn1 = mkConnection "ludvigsen" "vpn1";
    interfaces.vpn1.network = "site-vpn";
    interfaces.vpn1.virtual = true;
  };

  nodes.buskerud = mkDevice "buskerud" {
    interfaceGroups = [ ["eth1"] ];
  };

  nodes.shark = {
    guestType = "proxmox";
    parent = config.nodes.buskerud.id;
  };

  ### Powerpuff

  nodes.powerpuff-cluster = mkDevice "powerpuff-cluster" {
    interfaceGroups = [ ["eth1"] ];
  };

  nodes.kommode = {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
  };

  nodes.bicep = {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
  };

  nodes.ustetind = {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
  };

  ### PVV

  nodes.ntnu-veggen = mkRouter "NTNU-Veggen" {
    interfaceGroups = [ ["wan1"] ["eth1"] ];
    connections.eth1 = mkConnection "ludvigsen" "eth1";
  };

  nodes.ludvigsen = mkRouter "ludvigsen" {
    interfaceGroups = [ ["eth1"] ["eth2"] ["vpn1"] ];
    connections.eth2 = mkConnection "pvv-switch" "eth1";
    interfaces.vpn1.network = "site-vpn";
    interfaces.vpn1.virtual = true;
    interfaces.eth1.network = "ntnu";
    interfaces.eth2.network = "pvv";
  };

  nodes.pvv-switch = mkSwitch "PVV Switch (Terminalrommet)" {
    interfaceGroups = [ ["eth1" "eth2" "eth3"] ];
    connections.eth2 = mkConnection "brzeczyszczykiewicz" "eno1";
    connections.eth3 = mkConnection "georg" "eno1";
  };


  ### Openstack

  nodes.stackit = mkDevice "stackit" {
    interfaceGroups = [ ["*"] ];
  };

  nodes.ildkule = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;
  };
  nodes.wenche = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;
  };
  nodes.bakke = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;
  };
}
