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



# helpers

[no-exit-message]
_a_machine:
  #!/usr/bin/env -S sh -euo pipefail
  machines="$(
    nix eval {{nix_eval_opts}} .#nixosConfigurations --apply builtins.attrNames --json | jq .[] -r
  )"
  [ -n "$machines" ] || { echo >&2 "ERROR: no machines found"; false; }
  if [ -s .direnv/vars/last-machine.txt ]; then
    machines="$(
      grep <<<"$machines" -xF  "$(cat .direnv/vars/last-machine.txt)" ||:
      grep <<<"$machines" -xFv "$(cat .direnv/vars/last-machine.txt)" ||:
    )"
  fi
  choice="$(gum filter <<<"$machines")"
  mkdir -p .direnv/vars
  cat <<<"$choice" >.direnv/vars/last-machine.txt
  cat <<<"$choice"
