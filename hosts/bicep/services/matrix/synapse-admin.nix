{
  config,
  lib,
  pkgs,
  ...
}:

# This service requires you to have access to endpoints not available over the internet
# Use an ssh proxy or similar to access this dashboard.
# Then go into your developer console, storage, and change the baseurl to the local ip for synapse

{
  services.nginx.virtualHosts."localhost" = {
    rejectSSL = true;
    root = pkgs.synapse-admin;
  };
}
