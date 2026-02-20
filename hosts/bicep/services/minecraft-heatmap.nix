{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.minecraft-heatmap;
in
{
  sops.secrets."minecraft-heatmap/ssh-key/private" = {
    mode = "600";
  };

  sops.secrets."minecraft-heatmap/postgres-passwd" = {
    mode = "600";
  };

  services.minecraft-heatmap = {
    enable = true;
    database = {
      host = "postgres.pvv.ntnu.no";
      port = 5432;
      name = "minecraft_heatmap";
      user = "minecraft_heatmap";
      passwordFile = config.sops.secrets."minecraft-heatmap/postgres-passwd".path;
    };
  };

  systemd.services.minecraft-heatmap-ingest-logs = lib.mkIf cfg.enable {
    serviceConfig.LoadCredential = [
      "sshkey:${config.sops.secrets."minecraft-heatmap/ssh-key/private".path}"
    ];

    preStart =
      let
        knownHostsFile = pkgs.writeText "minecraft-heatmap-known-hosts" ''
          innovation.pvv.ntnu.no ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE9O/y5uqcLKCodg2Q+XfZPH/AoUIyBlDhigImU+4+Kn
          innovation.pvv.ntnu.no ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQClR9GvWeVPZHudlnFXhGHUX5sGX9nscsOsotnlQ4uVuGsgvRifsVsuDULlAFXwoV1tYp4vnyXlsVtMddpLI5ANOIDcZ4fgDxpfSQmtHKssNpDcfMhFJbfRVyacipjA4osxTxvLox/yjtVt+URjTHUA1MWzEwc26KfiOvWO5tCBTan7doN/4KOyT05GwBxwzUAwUmoGTacIITck2Y9qp4+xFYqehbXqPdBb15hFyd38OCQhtU1hWV2Yi18+hJ4nyjc/g5pr6mW09ULlFghe/BaTUXrTisYC6bMcJZsTDwsvld9581KPvoNZOTQhZPTEQCZZ1h54fe0ZHuveVB3TIHovZyjoUuaf4uiFOjJVaKRB+Ig+Il6r7tMUn9CyHtus/Nd86E0TFBzoKxM0OFu88oaUlDtZVrUJL5En1lGoimajebb1JPxllFN5hqIT+gVyMY6nRzkcfS7ieny/U4rzXY2rfz98selftgh3LsBywwADv65i+mPw1A/1QdND1R6fV4U=
          innovation.pvv.ntnu.no ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNjl3HfsDqmALWCL9uhz9k93RAD2565ndBqUh4N/rvI7MCwEJ6iRCdDev0YzB1Fpg24oriyYoxZRP24ifC2sQf8=
        '';
      in
      ''
        mkdir -p '${cfg.minecraftLogsDir}'
        "${lib.getExe pkgs.rsync}" \
        --archive \
        --verbose \
        --progress \
        --no-owner \
        --no-group \
        --rsh="${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=\"${knownHostsFile}\" -i \"$CREDENTIALS_DIRECTORY\"/sshkey" \
        root@innovation.pvv.ntnu.no:/ \
        '${cfg.minecraftLogsDir}'/
      '';
  };
}
