{ ... }:
{
  boot.blacklistedKernelModules = [
    # Obscure network protocols
    "appletalk"
    "atm"
    "ax25"
    "batman-adv"
    "can"
    "netrom"
    "psnap"
    "rds"
    "rose"
    "sctp"
    "tipc"

    # Filesystems we don't use
    "adfs"
    "affs"
    "befs"
    "bfs"
    "cifs"
    "cramfs"
    "efs"
    "exofs"
    "orangefs"
    "freevxfs"
    "gfs2"
    "hfs"
    "hfsplus"
    "hpfs"
    "jffs2"
    "jfs"
    "minix"
    "nilfs2"
    "ntfs"
    "omfs"
    "qnx4"
    "qnx6"
    "sysv"
    "ubifs"
    "ufs"

    # Legacy hardware
    "pcspkr"
    "floppy"
    "parport"
    "ppdev"

    # Other stuff we don't use
    "firewire-core"
    "firewire-ohci"
    "ksmbd"
    "ib_core"
    "l2tp_eth"
    "l2tp_netlink"
    "l2tp_ppp"
    "nfc"
    "soundwire"
  ];
}
