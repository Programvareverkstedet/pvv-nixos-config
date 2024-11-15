{
  imports = [
    ./exchange.nix
  ];

  services.taler = {
    settings = {
      taler.CURRENCY = "SCHPENN";
    };
  };
}
