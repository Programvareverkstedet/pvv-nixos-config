{ ... }:
{
  boot.blacklistedKernelModules = [
    # Obscure network protocols
    "appletalk"
    "atm"
    "ax25"
    "batman-adv"
    "can"
    "dccp"
    "ipx"
    "llc"
    "n-hdlc"
    "netrom"
    "p8022"
    "p8023"
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
    "orangefs"
    "qnx4"
    "qnx6"
    "sysv"
    "ubifs"
    "udf"
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

  # security.lockKernelModules = true;
  security.protectKernelImage = true;
}
