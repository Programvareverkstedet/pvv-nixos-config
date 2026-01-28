{ config, ... }:
{
  imports = [
    ./synapse-admin.nix
    ./synapse-auto-compressor.nix
    ./synapse.nix
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
