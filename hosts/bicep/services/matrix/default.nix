{ config, ... }:

{

  imports = [
    ./synapse.nix
    ./synapse-admin.nix
    ./element.nix
    ./coturn.nix
    ./mjolnir.nix
    ./well-known.nix

    # ./discord.nix
    ./out-of-your-element.nix
    ./hookshot
  ];



}
