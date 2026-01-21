{ config, ... }:

{

  imports = [
    ./synapse.nix
    ./synapse-admin.nix
    ./element.nix
    ./coturn.nix
    ./livekit.nix
    ./mjolnir.nix
    ./well-known.nix

    # ./discord.nix
    ./out-of-your-element.nix
    ./hookshot
  ];



}
