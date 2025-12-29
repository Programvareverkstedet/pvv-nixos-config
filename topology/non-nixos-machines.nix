{ config, lib, ... }:
let
  inherit (config.lib.topology) mkDevice;
in {
  nodes.balduzius = mkDevice "balduzius" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
  };
  nodes.tom = mkDevice "tom" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
  };
  nodes.hildring = mkDevice "hildring" {
    guestType = "proxmox";
    parent = config.nodes.powerpuff-cluster.id;
  };
  nodes.microbel = mkDevice "microbel" {
    interfaceGroups = [ [ "eth0" ] ];
  };
  nodes.innovation = mkDevice "innovation" {
    hardware.info = "Dell Optiplex 9010";
    interfaceGroups = [ [ "em0" ] ];
    interfaces.em0 = {
      mac = "18:03:73:20:18:d3";
      addresses = [
        "129.241.210.214"
        "2001:700:300:1900::1:56"
      ];
      gateways = [
        "129.241.210.129"
        "2001:700:300:1900::1"
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
    interfaceGroups = [ [ ] ];
  };
  nodes.sleipner = mkDevice "sleipner" {
    interfaceGroups = [ [ "eno0" "enp2s0" ] ];
  };
  nodes.isvegg = mkDevice "isvegg" {
    interfaceGroups = [ [ ] ];
  };
  nodes.ameno = mkDevice "ameno" {
    interfaceGroups = [ [ ] ];
  };
  nodes.skrott = mkDevice "skrott" {
    deviceType = "terminal";
    interfaceGroups = [ [ ] ];
  };
  nodes.torskas = mkDevice "torskas" {
    deviceType = "terminal";
    interfaceGroups = [ [ ] ];
  };
  nodes.wegonke = mkDevice "wegonke" {
    deviceType = "terminal";
    interfaceGroups = [ [ ] ];
  };
  nodes.demiurgen = mkDevice "demiurgen" {
    deviceType = "terminal";
    interfaceGroups = [ [ ] ];
  };
  nodes.sanctuary = mkDevice "sanctuary" {
    deviceType = "terminal";
    interfaceGroups = [ [ ] ];
  };
}
