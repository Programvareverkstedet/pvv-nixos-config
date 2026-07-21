{ config, lib, pkgs, ... }:
{
  security.audit = {
    enable = lib.mkDefault true;

    # NOTE: see auditctl(8) for the meaning of the different rule flags.
    rules = [
      # Kernel module loading/unloading
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k kernel-modules"

      # Mount/unmount by real (non-service) users
      "-a always,exit -F arch=b64 -S mount,umount2 -F auid>=1000 -F auid!=-1 -k mounts"

      # DAC permission/ownership changes by real users
      "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -k perm-mod"
      "-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -k perm-mod"
      "-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=-1 -k perm-mod"

      # Failed access attempts (permission denied) by real users
      "-a always,exit -F arch=b64 -S open,openat,creat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=-1 -k access"
      "-a always,exit -F arch=b64 -S open,openat,creat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=-1 -k access"

      # File deletion/rename by real users
      "-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=-1 -k delete"

      # Execution of privileged commands
      "-w ${config.security.wrapperDir}/sudo -p x -k privileged-sudo"
      "-w ${config.security.wrapperDir}/su -p x -k privileged-su"

      # Read of files containing secrets.
      "-w /var/lib/sops-nix/key.txt -p r -k secrets"
      "-w /run/secrets -p r -k secrets"
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
    plugins.syslog.active = true;
    plugins.af_unix.active = true;
  };
}
