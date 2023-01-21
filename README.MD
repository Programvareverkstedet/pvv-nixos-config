# PVV NixOS configs

## Hvordan endre på ting

Før du endrer på ting husk å ikke putte ting som skal være hemmelig uten å først lese seksjonen for hemmeligheter!

Etter å ha klonet prosjektet ned og gjort endringer kan du bygge med:

`nix build .#nixosConfigurations.jokum.config.system.build.toplevel`

Husk å hvertfall stage nye filer om du har laget dem!

Om alt bygger fint commit det og push til git repoet.
Det er sikkert lurt å lage en PR først om du ikke er vandt til nix enda.

Innen 24h skal alle systemene hente ned den nye konfigurasjonen og deploye den.

Du kan tvinge en maskin til å oppdatere seg før dette ved å kjøre:
`nixos-rebuild switch --update-input nixpkgs --update-input unstable --no-write-lock-file --refresh --flake git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git --upgrade`

som root på maskinen.

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
