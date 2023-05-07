{ config, ... }:

{

  imports = [
    ./synapse.nix
    ./synapse-admin.nix
    ./element.nix
    ./coturn.nix
    ./mjolnir.nix

    ./discord.nix
  ];

  

}
