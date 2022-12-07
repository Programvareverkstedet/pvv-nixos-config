{ config, ... }:

{

  imports = [
    ./synapse.nix
    ./synapse-admin.nix
    ./element.nix
    ./coturn.nix

    ./discord.nix
  ];

  

}
