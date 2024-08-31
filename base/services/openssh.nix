{ ... }:
{
  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAcceptedAlgorithms=+ssh-rsa
      Match Group wheel
        PasswordAuthentication no
      Match All
    '';
    settings.PermitRootLogin = "yes";
  };
}