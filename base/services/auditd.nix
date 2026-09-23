{ config, lib, pkgs, ... }:
let
  systemdExe = "${config.systemd.package}/lib/systemd/systemd";
in
{
  security.audit = {
    enable = lib.mkDefault true;

    # NOTE: see auditctl(8) for the meaning of the different rule flags.
    rules = [
      # Systemd uses a lot of eBPF programs for sandboxing and whatnot,
      # and logging this comes enabled by default. Let's not.
      "-a exclude,always -F msgtype=BPF"

      # Kernel module loading/unloading
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k kernel-modules"

      # Mount/unmount by real (non-service) users. Excludes the mounting
      # done by systemd --user instances.
      "-a always,exit -F arch=b64 -S mount,umount2 -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k mounts"

      # DAC permission/ownership changes by real users. Same systemd caveat
      # as above.
      "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k perm-mod"
      "-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k perm-mod"
      "-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k perm-mod"

      # Failed access attempts (permission denied) by real users
      "-a always,exit -F arch=b64 -S open,openat,creat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k access"
      "-a always,exit -F arch=b64 -S open,openat,creat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k access"

      # File deletion/rename by real users.
      "-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=-1 -F exe!=${systemdExe} -k delete"

      # Execution of privileged commands
      "-w ${config.security.wrapperDir}/sudo -p x -k privileged-sudo"
      "-w ${config.security.wrapperDir}/su -p x -k privileged-su"

      # Read of files containing secrets.
      "-w /etc/ssh/ssh_host_ed25519_key -p r -k secrets"
      "-w /etc/ssh/ssh_host_rsa_key -p r -k secrets"

      # NixOS generation switching
      "-w /nix/var/nix/profiles -p wa -k nixos-generation-switch"

      # Switching bootloader content
      "-w /boot -p wa -k boot-tampering"

      # Login records
      "-w /var/lib/lastlog2 -p wa -k logins"

      # Write or append to the audit trail
      "-w /var/log/audit -p wa -k audit-log-tampering"
      "-w ${lib.getExe' pkgs.audit "auditctl"} -p x -k audit-tools"
    ];
  };

  security.auditd = {
    enable = lib.mkDefault true;
    plugins.af_unix.active = true;
    plugins.laurel = {
      active = true;
      format = "string";
      path = lib.getExe' pkgs.laurel "laurel";
      args = let
        laurelConfig = (pkgs.formats.toml { }).generate "laurel-config.toml" {
          directory = "/var/log/laurel";
          user = "laurel";
          auditlog.file = "| ${pkgs.writeShellScript "laurel-to-syslog" ''
            exec ${lib.getExe' pkgs.util-linux "logger"} --tag laurel --priority daemon.info --size ${toString (1024 * 256)}
          ''}";
        };
      in [ "--config" "${laurelConfig}" ];
    };
  };

  systemd.services.auditd.serviceConfig = {
    LogsDirectory = [ "laurel" ];
    Slice = "system-monitoring.slice";
  };

  users.users.laurel = {
    isSystemUser = true;
    group = "laurel";
  };
  users.groups.laurel = { };
}
