{
  services.qotd = {
    enable = true;
    quotes = builtins.fromJSON (builtins.readFile ./quotes.json);
  };
}
