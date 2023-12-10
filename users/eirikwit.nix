{ pkgs, ... }:
{
  users.users.eirikwit = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "drift"
    ];

    packages = with pkgs; [
      micro
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZusOSiUVSMjrvNdUq4R91Gafq4XVs9C77Zt+LMPhCU eirikw@live.no"
    ];
  };
}
