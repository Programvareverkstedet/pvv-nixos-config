{ ... }:

{
  boot.blacklistedKernelModules = [
  "rxrpc" # dirtyfrag
  "esp6" # dirtyfrag
  "esp4" # dirtyfrag
];
boot.extraModprobeConfig = ''
  # dirtyfrag
  install esp4 /bin/false
  # dirtyfrag
  install esp6 /bin/false
  # dirtyfrag
  install rxrpc /bin/false
'';
}
