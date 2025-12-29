# Miscellaneous development notes

This document contains a bunch of information that is not particularly specific to the pvv nixos config,
but concerns technologies we use often or gotchas to be aware of when working with NixOS. A lot of the information
here is already public information spread around the internet, but we've collected some of the items we use often
here.

## The firewall

`networking.firewall` is a NixOS module that configures `iptables` rules on the machine. It is enabled by default on
all of our machines, and it can be easy to forget about it when setting up new services, especially when we are the
ones creating the NixOS module.

When setting up a new service that listens on a TCP or UDP port, make sure to add the appropriate ports to either
`networking.firewall.allowedTCPPorts` or `networking.firewall.allowedUDPPorts`.

You can list out the current firewall rules by running `sudo iptables -L -n -v` on the machine.

## Finding stuff

Finding stuff, both underlying implementation and usage is absolutely crucial when working on nix.
Oftentimes, the documentation will be outdated, lacking or just plain out wrong. These are some of
the techniques we have found to be quite good when working with nix.

### [ripgrep](https://github.com/BurntSushi/ripgrep)

ripgrep (or `rg` for short) is a tool that lets you recursively grep for regex patters in a directory.

It is great for finding references to configuration, and where and how certain things are used. It is
especially great when working with [nixpkgs](https://github.com/NixOS/nixpkgs), which is quite large.

### GitHub Search

When trying to set up a new service or reconfigure something, it is very common that someone has done it
before you, but it has never been documented anywhere. A lot of Nix code exists on GitHub, and you can
easily query it by using the `lang:nix` filter in the search bar.

For example: https://github.com/search?q=lang%3Anix+dibbler&type=code

## rsync

`rsync` is a tool for synchronizing files between machines. It is very useful when transferring large
amounts of data from a to b. We use it for multiple things, often when data is produced or stored on
one machine, and we want to process or convert it on another. For example, we use it to transfer gitea
artifacts, to transfer gallery pictures, to transfer minecraft world data for map rendering, and more.

Along with `rsync`, we often use a lesser known tool called `rrsync`, which you can use inside an ssh
configuration (`authorized_keys` file) to restrict what paths a user can access when connecting over ssh.
This is useful both as a security measure, but also to avoid accidental overwrites of files outside the intended
path. `rrsync` will use chroot to restrict what paths the user can access, as well as refuse to run arbitrary commands.

## `nix repl`

`nix repl` is an interactive REPL for the Nix language. It is very useful for experimenting with Nix code,
and testing out small snippets of code to make sure it behaves as expected. You can also use it to explore
NixOS machine configurations, to interactively see that the configuration evaluates to what you expect.

```
# While in the pvv-nixos-config directory
nix repl .

# Upon writing out the config path and clickin [Tab], you will get autocompletion suggestions:
nix-repl> nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts._
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.bekkalokk.pvv.ntnu.no-nixos-metrics
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.idp.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.minecraft.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.pvv.org
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.pw.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.roundcubeplaceholder.example.com
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.snappymail.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.webmail.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.wiki.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.www.pvv.ntnu.no
nixosConfigurations.bekkalokk.config.services.nginx.virtualHosts.www.pvv.org
```

## `nix why-depends`

If you ever wonder why a certain package is being used as a dependency of another package,
or another machine, you can use `nix why-depends` to find the dependency path from one package to another.
This is often useful after updating nixpkgs and finding an error saying that a certain package is insecure,
broken or whatnot. You can do something like the following

```bash
# Why does bekkalokk depend on openssl?
nix why-depends .#nixosConfigurations.bekkalokk.config.system.build.toplevel .#nixosConfigurations.bekkalokk.pkgs.openssl

# Why does bekkalokk's minecraft-server depend on zlib? (this is not real)
nix why-depends .#nixosConfigurations.bekkalokk.pkgs.minecraft-server .#nixosConfigurations.bekkalokk.pkgs.zlib
```

## php-fpm

php-fpm (FastCGI Process Manager) is a PHP implementation that is designed for speed and production use. We host a bunch
of different PHP applications (including our own website), and so we use php-fpm quite a bit. php-fpm typically exposes a
unix socket that nginx will connect to, and php-fpm will then render php upon web requests forwarded from nginx and return
it.

php-fpm has a tendency to be a bit hard to debug. It is not always very willing to spit out error messages and logs, and so
it can be a bit hard to figure out what's up when something goes wrong. You should see some of the commented stuff laying around
in the website code on bekkalokk for examples of how to configure php-fpm for better logging and error reporting.
