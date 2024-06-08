{config, ...}:
{

  sops.secrets."bluemap_ssh_key" = {
    owner = "root";
    mode = "0400";
  };

  services.bluemap = {
    enable = true;
    eula = true;
    defaultWorld = "/var/lib/bluemap/vanilla";
    host = "minecraft.pvv.ntnu.no";
  };

  systemd.services."render-bluemap-maps".preStart = ''
    rsync -e 'ssh -i ${config.sops.secrets."bluemap_ssh_key".path} -o "StrictHostKeyChecking accept-new"' \
      root@innovation.pvv.ntnu.no:/var/backups/minecraft/current/ \
      /var/lib/bluemap/vanilla"
    '';
}
