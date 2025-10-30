{ config, ... }:
let
  cfg = config.services.gitea;
  cacheDir = "/var/cache/${config.systemd.services.gitea.serviceConfig.CacheDirectory}";
in
{
  systemd.services."gitea-vaskepersonalet" = {
    description = "yeeet";
    startAt = "hourly";

    serviceConfig = rec {
      User = cfg.user;
      Group = cfg.group;

      RuntimeDirectory = "gitea-vaskepersonalet";
      RootDirectory = "/run/${RuntimeDirectory}";

      BindPaths = [
        builtins.storeDir
        cacheDir
        cfg.dump.backupDir
      ];
    };

    script = let
      percentageLimit = 80;
    in ''
      USED=$(df --output=pcent '${cacheDir}' | grep '[0-9]' | tr -d '%')
      if [[ $USED -lt ${toString percentageLimit} ]]; then exit 0; fi

      echo "omg omg, we're running out of space, imma yeet the cache"

      rm -rf '${cacheDir}'/*
      echo "yeetus deletus"

      USED=$(df --output=pcent '${cacheDir}' | grep '[0-9]' | tr -d '%')
      if [[ $USED -lt ${toString percentageLimit} ]]; then exit 0; fi

      echo ""
      echo "bruh, still low on space, yeeting old backups"
      echo ""

      # tail -n+2 ensure we keep at least one backup.
      for file in $(ls -t1 '${cfg.dump.backupDir}' | sort --reverse | tail -n+2); do
        echo "> Chose $file"
        echo "> Do you really want to release this pokemon? [Y/n] Y"
        rm "$file"
        echo "> ..."
        echo "> The pokemon was released back into the wild"
        echo ""

        USED=$(df --output=pcent '${cacheDir}' | grep '[0-9]' | tr -d '%')
        if [[ $USED -lt ${toString percentageLimit} ]]; then exit 0; fi
      done

      echo "No way, we're still out of space? Not my problem anymore"
    '';
  };
}
