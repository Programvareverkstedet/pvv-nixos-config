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
}