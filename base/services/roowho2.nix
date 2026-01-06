{ lib, values, ... }:
{
  services.roowho2.enable = lib.mkDefault true;

  systemd.sockets.roowho2-rwhod.socketConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      "127.0.0.1"
      values.ipv4-space
    ];
  };
}
