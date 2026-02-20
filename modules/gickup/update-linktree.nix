{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.gickup;
in
{
  config = lib.mkIf cfg.enable {
    # TODO: run upon completion of cloning a repository
    systemd.timers."gickup-linktree" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "gickup-linktree.service";
      };
    };

    # TODO: update symlink for one repo at a time (e.g. gickup-linktree@<instance>.service)
    systemd.services."gickup-linktree" = {
      after = map ({ slug, ... }: "gickup@${slug}.service") (lib.attrValues cfg.instances);
      wantedBy = [ "gickup.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          let
            script = pkgs.writeShellApplication {
              name = "gickup-update-symlink-tree.sh";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.findutils
              ];
              text = ''
                shopt -s nullglob

                for repository in ./*/*/*; do
                  REPOSITORY_RELATIVE_DIRS=''${repository#"./"}

                  echo "Checking $REPOSITORY_RELATIVE_DIRS"

                  declare -a REVISIONS
                  readarray -t REVISIONS < <(find "$repository" -mindepth 1 -maxdepth 1 -printf "%f\n" | sort --numeric-sort --reverse)

                  if [[ "''${#REVISIONS[@]}" == 0 ]]; then
                    echo "Found no revisions for $repository, continuing"
                    continue
                  fi

                  LAST_REVISION="''${REVISIONS[0]}"
                  SYMLINK_PATH="../linktree/''${REPOSITORY_RELATIVE_DIRS}"

                  mkdir -p "$(dirname "$SYMLINK_PATH")"

                  EXPECTED_SYMLINK_TARGET=$(realpath "''${repository}/''${LAST_REVISION}")
                  EXISTING_SYMLINK_TARGET=$(realpath "$SYMLINK_PATH" || echo "<none>")

                  if [[ "$EXISTING_SYMLINK_TARGET" != "$EXPECTED_SYMLINK_TARGET" ]]; then
                    echo "Updating symlink for $REPOSITORY_RELATIVE_DIRS"
                    rm "$SYMLINK_PATH" ||:
                    ln -rs "$EXPECTED_SYMLINK_TARGET" "$SYMLINK_PATH"
                  else
                    echo "Symlink already up to date, continuing..."
                  fi

                  echo "---"
                done
              '';
            };
          in
          lib.getExe script;

        User = "gickup";
        Group = "gickup";

        BindPaths = lib.optionals (cfg.dataDir != "/var/lib/gickup") [
          "${cfg.dataDir}:/var/lib/gickup"
        ];

        Slice = "system-gickup.slice";

        StateDirectory = "gickup";
        WorkingDirectory = "/var/lib/gickup/raw";

        # Hardening options
        # TODO:
        PrivateNetwork = true;
      };
    };
  };
}
