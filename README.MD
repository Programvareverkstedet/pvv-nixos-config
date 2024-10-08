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

## Seksjonen for hemmeligheter

For at hemmeligheter ikke skal deles med hele verden i git - eller å være world
readable i nix-storen, bruker vi [sops-nix](https://github.com/Mic92/sops-nix)

For å legge til secrets kan du kjøre f.eks. `sops secrets/jokum/jokum.yaml`
Dette vil dekryptere filen og gi deg en text-editor du kan bruke for endre hemmelighetene.

Et nix shell med dette verktøyet inkludert ligger i flaket og shell.nix og kan aktiveres med:

`nix-shell` eller `nix develop`. Vi anbefaler det siste.
I tilegg kan du sette opp [direnv](https://direnv.net/) slik at dette skjer automatisk

for å få tilgang til å lese/skrive hemmeligheter må du spørre noen/noe som har tilgang til hemmelighetene
om å legge til age eller pgp nøkkelen din i [`.sops.yaml`](https://git.pvv.ntnu.no/Drift/pvv-nixos-config/src/main/.sops.yaml)

Denne kan du generere fra ssh-nøkkelene dine eller lage en egen nøkkel.

### Legge til flere keys

Gjør det som gir mening i .sops.yml

Etter det kjør `sops updatekeys secrets/host/file.yml`

MERK at det ikke er `sops -r` som BARE roterer nøkklene for de som allerede er i secretfila
