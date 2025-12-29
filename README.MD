# PVV NixOS configs

## Hvordan endre på ting

Før du endrer på ting husk å ikke putte ting som skal være hemmelig uten å først lese seksjonen for hemmeligheter!

Etter å ha klonet prosjektet ned og gjort endringer kan du evaluere configene med:

`nix flake check --keep-going`

før du bygger en maskin med:

`nix build .#<maskinnavn>`

hvis du vil være ekstra sikker på at alt bygger så kan du kjøre:

`nix build .` for å bygge alle de viktige maskinene.

NB: Dette kan ta opp til 30 minutter avhengig av hva som ligger i caches

Husk å hvertfall stage nye filer om du har laget dem!

Om alt bygger fint commit det og push til git repoet.
Det er sikkert lurt å lage en PR først om du ikke er vandt til nix enda.

Innen 24h skal alle systemene hente ned den nye konfigurasjonen og deploye den.

Du kan tvinge en maskin til å oppdatere seg før dette ved å kjøre:
`nixos-rebuild switch --update-input nixpkgs --update-input nixpkgs-unstable --no-write-lock-file --refresh --upgrade --flake git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git`

som root på maskinen.

Hvis du ikke har lyst til å oppdatere alle pakkene (og kanskje måtte vente en stund!) kan du kjøre

`nixos-rebuild switch --override-input nixpkgs nixpkgs --override-input nixpkgs-unstable nixpkgs-unstable --flake git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git`

## Annen dokumentasjon

- [User management](./docs/users.md)
- [Secret management and `sops-nix`](./docs/secret-management.md)
