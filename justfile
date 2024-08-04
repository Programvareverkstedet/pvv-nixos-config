export GUM_FILTER_HEIGHT := "15"
nom := `if command -v nom >/dev/null; then echo nom; else echo nix; fi`

@_default:
  just "$(gum choose --ordered --header "Pick a recipie..." $(just --summary --unsorted))"

check:
  nix flake check --keep-going

build-machine machine=`just _a_machine`:
  {{nom}} build .#nixosConfigurations.{{ machine }}.config.system.build.toplevel

_a_machine:
  nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq .[] -r | gum filter
