export GUM_FILTER_HEIGHT := "15"
nom := `if command -v nom >/dev/null; then echo nom; else echo nix; fi`

@_default:
  just "$(gum choose --ordered --header "Pick a recipie..." $(just --summary --unsorted))"

check:
  nix flake check --keep-going

build-machine machine=`just _a_machine`:
  {{nom}} build .#nixosConfigurations.{{ machine }}.config.system.build.toplevel

run-vm machine=`just _a_machine`:
  nixos-rebuild build-vm --flake .#{{ machine }}
  QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::8081-:443,hostfwd=tcp::2222-:22" ./result/bin/run-*-vm

@update-inputs:
  nix eval .#inputs --apply builtins.attrNames --json \
    | jq '.[]' -r \
    | gum choose --no-limit --height=15 \
    | xargs -L 1 nix flake lock --update-input


_a_machine:
  nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq .[] -r | gum filter
