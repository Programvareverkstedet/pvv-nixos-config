{ config, ... }:
let
  inherit
    (config.lib.topology)
    mkInternet
    mkRouter
    mkSwitch
    mkDevice
    mkConnection
    mkConnectionRev;
  values = import ./values.nix;
in {

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
    interfaceGroups = [ ["eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7"] ];
    connections.eth2 = mkConnection "bekkalokk" "enp2s0";
    connections.eth3 = mkConnection "bicep" "enp6s0f0";
    connections.eth4 = mkConnection "buskerud" "enp3s0f0";
    connections.eth5 = mkConnection "knutsen" "eth1";
    connections.eth7 = mkConnection "joshua" "eth1";
  };

  nodes.knutsen = mkRouter "knutsen" {
    interfaceGroups = [ ["eth1"] ["eth2"] ["vpn1"] ];
    connections.eth2 = mkConnectionRev "brus-switch" "eth6";
    # connections.vpn1 = mkConnection "ludvigsen" "vpn1";
    interfaces.vpn1.network = "site-vpn";
    interfaces.vpn1.virtual = true;
  };

  nodes.joshua = mkDevice "joshua" {
    interfaceGroups = [ ["eth1"] ];
  };

  nodes.shark = {
    guestType = "proxmox";
    parent = config.nodes.joshua.id;
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
  nodes.bob = {
    guestType = "openstack";
    parent = config.nodes.stackit.id;
  };

}
