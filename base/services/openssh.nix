{ ... }:
{
  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    extraConfig = ''
      PubkeyAcceptedAlgorithms=+ssh-rsa
      Match Group wheel
        PasswordAuthentication no
      Match All
    '';
    settings.PermitRootLogin = "yes";

  };
  users.users."root".openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqVt4LCe0YIttr9swFxjkjn37ZDY9JxwVC+2gvfSINDJorOCtqPjDOTD2fTS1Gz08QCwpnLWq2kyvRchu6WgriAbSACpbZZBgxRaF/FVh3oiMVFGnNKGnv6/fdo/vZtu8mUVuqtmTrgLYpZdbR4oD3XiBlDKs7Cv5hPqt95lnP6MNFvE8mICCfd1PwhsABd2IQ5laz3u77/RXhNFJL0Kf2/+6gk9awcLuwHrPdvq7c3BxRHbc9UMRQENyjyQPa7aLe+uJBFLKP51I8VBuDpDacuibQx7nMt6N2UJ2KWI0JxRMHuJNq4S5jidR82aOw9gzGbTv30SKNLMqsZ0xj4LtdqCXDiZF6Lr09PsJYsvnBUFWa14HGcThKDtgwQwBryNViYmfv//0h9+RLZiU0ab+NEwSs7Zh5iAD+vhx64QqNX3tR7Le4SWXh8W0eShU9N78qYdSkiC3Ui7htxeqOocXM/P4AwbnHsLELIvkHdvgchCPvl8ygZa4WJTEWv16+ICskJcAKWGuqjvXAFuwjJJmPp9xLW9O0DFfQhMELiGamQR9wK07yYQVr34iah6qZO7cwhSKyEPFrVPIaNtfDhsjED639F7vmktf26SWNJHWfW0wOHILjI6TgqUvy0JDd8W8w0CHlAfz6Fs2l99NNgNF8dB3vBASbxS0hu/y0PVu/xQ== openstack-sleipner"

    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCbgJ0Uwh9VSVhfId7l9i5/jk4CvAK5rbkiab8R+moF root@sleipner"
  ];
}
