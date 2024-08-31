{ ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "drift@pvv.ntnu.no";
  };

  # Let's not spam LetsEncrypt in `nixos-rebuild build-vm` mode:
  virtualisation.vmVariant = {
    security.acme.defaults.server = "https://127.0.0.1";
    security.acme.preliminarySelfsigned = true;

    users.users.root.initialPassword = "root";
  };
}