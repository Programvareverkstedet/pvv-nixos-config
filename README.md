# PVV NixOS config

This repository contains the NixOS configurations for Programvareverkstedet's server closet.
In addition to machine configurations, it also contains a bunch of shared modules, packages, and
more.

## Machines

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
[wen]: https://wiki.pvv.ntnu.no/wiki/Maskiner/wenche
