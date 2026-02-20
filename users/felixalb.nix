{
  config,
  pkgs,
  lib,
  ...
}:
{
  users.users.felixalb = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ]
    ++ lib.optionals (config.users.groups ? "libvirtd") [
      "libvirtd"
    ];
    shell = if config.programs.zsh.enable then pkgs.zsh else pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBTXSL0w7OUcz1LzEt1T3I3K5RgyNV+MYz0x/1RbpDHQ felixalb@worf"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDKzPICGew7uN0cmvRmbwkwTCodTBUgEhkoftQnZuO4Q felixalb@pvv.ntnu.no"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJky33ynjqyWP+hh24gFCMFIEqe3CjIIowGM9jiPbT79 felixalb@sisko.home.feal.no"
    ];
  };
}
