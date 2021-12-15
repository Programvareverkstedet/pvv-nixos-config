{ pkgs, lib, config, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      rust-motd
      toilet
    ];

    loginShellInit = let
      motd = "${pkgs.rust-motd}/bin/rust-motd /etc/${config.environment.etc.rustMotdConfig.target}";
    in ''
      # Assure stdout is a terminal, so headless programs won't be broken
      if [ "x''${SSH_TTY}" != "x" ]; then
        ${motd}
      fi
    '';

    etc.rustMotdConfig = {
      target = "rust-motd-config.toml";
      source = let

        cfg = {
          global = {
            progress_full_character = "=";
            progress_empty_character = "=";
            progress_prefix = "[";
            progress_suffix = "]";
            time_format = "%Y-%m-%d %H:%M:%S";
          };

          banner = {
            color = "red";
            command = "hostname | ${pkgs.toilet}/bin/toilet -f mono9";
          };
          
          service_status = {
            Accounts = "accounts-daemon";
            Cron = "cron";
            Docker = "docker";
            Matrix = "matrix-synapse";
            sshd = "sshd";
          };
          
          uptime = {
            prefix = "Uptime: ";
          };
          
          # Not relevant for server
          # user_service_status = {
          #   Gpg-agent = "gpg-agent";
          # };
          
          filesystems = let
            inherit (lib.attrsets) attrNames listToAttrs nameValuePair;
            inherit (lib.lists) imap1;
            inherit (config) fileSystems;

            imap1Attrs' = f: set:
              listToAttrs (imap1 (i: attr: f i attr set.${attr}) (attrNames set));

            getName = i: v: if (v.label != null) then v.label else "<? ${toString i}>";
          in
            imap1Attrs' (i: n: v: nameValuePair (getName i v) n) fileSystems;
          
          memory = {
            swap_pos = "beside"; # or "below" or "none"
          };

          last_login = let
            inherit (lib.lists) imap1;
            inherit (lib.attrsets) filterAttrs nameValuePair attrValues listToAttrs;
            inherit (config.users) users;
            
            normalUsers = filterAttrs (n: v: v.isNormalUser || n == "root") users;
            userNPVs = imap1 (index: user: nameValuePair user.name index) (attrValues normalUsers);
          in listToAttrs userNPVs;

          last_run = {};
        };
      
        toml = pkgs.formats.toml {};

      in toml.generate "rust-motd.toml" cfg;
    };
  };
}
