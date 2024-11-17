{
  imports = [
    ./exchange.nix
    ./bank.nix
  ];

  services.taler = {
    settings = {
      taler.CURRENCY = "SCHPENN";
    };
  };
}
