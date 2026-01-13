# Development - working on the PVV machines

This document outlines the process of editing our NixOS configurations, and testing and deploying said changes
to the machines. Most of the information written here is specific to the PVV NixOS configuration, and the topics
will not really cover the nix code itself in detail. You can find some more resources for that by either following
the links from the *Upstream documentation* section below, or in [Miscellaneous development notes](./development-misc.md).

## Editing nix files

> [!WARNING]
> Before editing any nix files, make sure to read [Secret management and `sops-nix`](./secret-management.md)!
> We do not want to add any secrets in plaintext to the nix files, and certainly not commit and publish
> them into the common public.

The files are plaintext code, written in the [`Nix` language](https://nix.dev/manual/nix/stable/language/).

Below is a list of important files and directories, and a description of what they contain.

### `flake.nix`

The `flake.nix` file is a [nix flake](https://wiki.nixos.org/wiki/Flakes) and makes up the entrypoint of the
entire configuration. It declares what inputs are used (similar to dependencies), as well as what outputs the
flake exposes. In our case, the most important outputs are the `nixosConfigurations` (our machine configs), but
we also expose custom modules, packages, devshells, and more. You can run `nix flake show` to get an overview of
the outputs (however you will need to [enable the `nix-flakes` experimental option](https://wiki.nixos.org/wiki/Flakes#Setup)).

You will find that a lot of the flake inputs are the different PVV projects that we develop, imported to be hosted
on the NixOS machines. This makes it easy to deploy changes to these projects, as we can just update the flake input
to point to a new commit or version, and then rebuild the machines.

A NixOS configuration is usually made with the `nixpkgs.lib.nixosSystem` function, however we have a few custom wrapper
functions named `nixosConfig` and `stableNixosConfig` that abstracts away some common configuration we want on all our machines.

### `values.nix`

`values.nix` is a somewhat rare pattern in NixOS configurations around the internet. It contains a bunch of constant values
that we use throughout the configuration, such as IP addresses, DNS names, paths and more. This not only makes it easier to
change the values should we need to, but it also makes the configuration more readable. Instead of caring what exact IP any
machine has, you can write `values.machines.name.ipv4` and abstract the details away.

### `base`

The `base` directory contains a bunch of NixOS configuration that is common for all or most machines. Some of the config
you will find here sets defaults for certain services without enabling them, so that when they are enabled in a machine config,
we don't need to repeat the same defaults over again. Other parts actually enable certain services that we want on all machines,
such as `openssh` or the auto upgrade timer.

### Vendoring `modules` and `packages`

Sometimes, we either find that the packages or modules provided by `nixpkgs` is not sufficient for us,
or that they are bugged in some way that can not be easily overrided. There are also cases where the
modules or packages does not exist. In these cases, we tend to either copy and modify the modules and
packages from nixpkgs, or create our own. These modules and packages end up in the top-level `modules`
and `packages` directories. They are usually exposed in `flake.nix` as flake outputs `nixosModules.<name>`
and `packages.<platform>.<name>`, and they are usually also added to the machines that need them in the flake.

In order to override or add an extra package, the easiest way is to use an [`overlay`](https://wiki.nixos.org/wiki/Overlays).
This makes it so that the package from `pkgs.<name>` now refers to the modified variant of the package.

In order to add a module, you can just register it in the modules of the nixos machine.
In order to override a module, you also have to use `disabledModules = [ "<path-relative-to-nixpkgs/modules>" ];`.
Use `rg` to find examples of the latter.

Do note that if you believe a new module to be of high enough quality, or the change you are making to be
relevant for every nix user, you should strongly consider also creating a PR towards nixpkgs. However,
getting changes made there has a bit higher threshold and takes more time than making changes in the PVV config,
so feel free to make the changes here first. We can always remove the changes again once the upstreaming is finished.

### `users`, `secrets` and `keys`

For `users`, see [User management](./users.md)

For `secrets` and `keys`, see [Secret management and `sops-nix`](./secret-management.md)

### Collaboration

We use our gitea to collaborate on changes to the nix configuration. Every PVV maintenance member should have
access to the repository. The usual workflow is that we create a branch for the change we want to make, do a bunch
of commits and changes, and then open a merge request for review (or just rebase on master if you know what you are doing).

### Upstream documentation

Here are different sources of documentation and stuff that you might find useful while
writing, editing and debugging nix code.

 - [nixpkgs repository](https://github.com/NixOS/nixpkgs)

This is particularly useful to read the source code, as well as upstreaming pieces of code that we think
everyone would want

 - [NixOS search](https://search.nixos.org/)

This is useful for searching for both packages and NixOS options.

 - [nixpkgs documentation](https://nixos.org/manual/nixpkgs/stable/)
 - [NixOS documentation](https://nixos.org/manual/nixos/stable/)
 - [nix (the tool) documentation](https://nix.dev/manual/nix/stable/)

All of the three above make up the official documentation with all technical
details about the different pieces that makes up NixOS.

 - [The official NixOS wiki](https://wiki.nixos.org)

User-contributed guides, tips and tricks, and whatever else.

 - [nix.dev](https://nix.dev)

Additional stuff

 - [Noogle](https://noogle.dev)

This is useful when looking for nix functions and packaging helpers.

## Testing and deploying changes

After editing the nix files on a certain branch, you will want to test and deploy the changes to the machines.
Unfortunately, we don't really have a good setup for testing for runtime correctness locally, but we can at least
make sure that the code evaluates and builds correctly before deploying.

To just check that the code evaluates without errors, you can run:

```bash
nix flake check
# Or if you want to keep getting all errors before it quits:
nix flake check --keep-going
```

> [!NOTE]
> If you are making changes that involves creating new nix files, remember to `git add` those files before running
> any nix commands. Nix refuses to acknowledge files that are not either commited or at least staged. It will spit
> out an error message about not finding the file in question.

### Building machine configurations

To build any specific machine configuration and look at the output, you can run:

```bash
nix build .#nixosConfigurations.<machine-name>.config.system.build.toplevel
# or just
nix build .#<machine-name>
```

This will create a symlink name `./result` to a directory containing the built NixOS system. It is oftentimes
the case that config files for certain services only end up in the nix store without being put into `/etc`. If you wish
to read those files, you can often find them by looking at the systemd unit files in `./result/etc/systemd/system/`.
(if you are using vim, `gf` or go-to-file while the cursor is over a file path is a useful trick while doing this).

If you have edited something that affects multiple machines, you can also build all important machines at once by running:

```bash
nix build .#
```

> [!NOTE]
> Building all machines at once can take a long time, depending on what has changed and whether you have already
> built some of the machines recently. Be prepared to wait for up to an hour to build all machines from scratch
> if this is the first time.

### Forcefully reset to `main`

If you ever want to reset a machine to the `main` branch, you can do so by running:

```bash
nixos-rebuild switch --update-input nixpkgs --update-input nixpkgs-unstable --no-write-lock-file --refresh --upgrade --flake git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git
```

This will ignore the current branch and just pull the latest `main` from the git repository directly from gitea.
You can also use this command if there are updates on the `main` branch that you want to deploy to the machine without
waiting for the nightly rebuild.
