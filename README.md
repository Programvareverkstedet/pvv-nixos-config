# PVV NixOS config

This repository contains the NixOS configurations for Programvareverkstedet's server closet.
In addition to machine configurations, it also contains a bunch of shared modules, packages, and
more.

> [!WARNING]
> Please read [Development - working on the PVV machines](./docs/development.md) before making
> any changes, and [Secret management and `sops-nix`](./docs/secret-management.md) before adding
> any credentials such as passwords, API tokens, etc. to the configuration.

## Deploying to machines

> [!WARNING]
> Be careful to think about state when testing changes against the machines. Sometimes, a certain change
> can lead to irreversible changes to the data stored on the machine. An example would be a set of database
> migrations applied when testing a newer version of a service. Unless that service also comes with downwards
> migrations, you can not go back to the previous version without losing data.

To deploy the changes to a machine, you should first SSH into the machine, and clone the pvv-nixos-config
repository unless you have already done so. After that, checkout the branch you want to deploy from, and rebuild:

```bash
# Run this while in the pvv-nixos-config directory
sudo nixos-rebuild switch --update-input nixpkgs --update-input nixpkgs-unstable --no-write-lock-file --refresh --flake .# --upgrade
```

This will rebuild the NixOS system on the current branch and switch the system configuration to reflect the new changes.

Note that unless you eventually merge the current changes into `main`, the machine will rebuild itself automatically and
revert the changes on the next nightly rebuild (tends to happen when everybody is asleep).

## Machine overview

| Name                       | Type     | Description                                               |
|----------------------------|----------|-----------------------------------------------------------|
| [bekkalokk][bek]           | Physical | Our main web host, webmail, wiki, idp, minecraft map, ... |
| [bicep][bic]               | Virtual  | Database host, matrix, git mirrors, ...                   |
|  bikkje                    | Virtual  | Experimental login box                                    |
| [brzeczyszczykiewicz][brz] | Physical | Shared music player                                       |
| [georg][geo]               | Physical | Shared music player                                       |
| [ildkule][ild]             | Virtual  | Logging and monitoring host, prometheus, grafana, ...     |
| [kommode][kom]             | Virtual  | Gitea + Gitea pages                                       |
| [lupine][lup]              | Physical | Gitea CI/CD runners                                       |
|  shark                     | Virtual  | Test host for authentication, absolutely horrendous       |
| [skrot/skrott][skr]        | Physical | Kiosk, snacks and soda                                    |
| [wenche][wen]              | Virtual  | Nix-builders, general purpose compute                     |

## Documentation

- [Development - working on the PVV machines](./docs/development.md)
- [Miscellaneous development notes](./docs/development-misc.md)
- [User management](./docs/users.md)
- [Secret management and `sops-nix`](./docs/secret-management.md)

[bek]: https://wiki.pvv.ntnu.no/wiki/Maskiner/bekkalokk
[bic]: https://wiki.pvv.ntnu.no/wiki/Maskiner/bicep
[brz]: https://wiki.pvv.ntnu.no/wiki/Maskiner/brzęczyszczykiewicz
[geo]: https://wiki.pvv.ntnu.no/wiki/Maskiner/georg
[ild]: https://wiki.pvv.ntnu.no/wiki/Maskiner/ildkule
[kom]: https://wiki.pvv.ntnu.no/wiki/Maskiner/kommode
[lup]: https://wiki.pvv.ntnu.no/wiki/Maskiner/lupine
[skr]: https://wiki.pvv.ntnu.no/wiki/Maskiner/Skrott
[wen]: https://wiki.pvv.ntnu.no/wiki/Maskiner/wenche
