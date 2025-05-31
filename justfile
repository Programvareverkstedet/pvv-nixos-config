set positional-arguments # makes variables accesible as $1 $2 $@
export GUM_FILTER_HEIGHT := "15"
nom := `if [[ -t 2 ]] && command -v nom >/dev/null; then echo nom; else echo nix; fi`
nix_eval_opts := "--log-format raw --option warn-dirty false"

@_default:
  just "$(gum choose --ordered --header "Pick a recipie..." $(just --summary --unsorted))"

check *_:
  nix flake check --keep-going "$@"

build-machine machine=`just _a_machine` *_:
  {{nom}} build .#nixosConfigurations.{{ machine }}.config.system.build.toplevel "${@:2}"

run-vm machine=`just _a_machine` *_:
  nixos-rebuild build-vm --flake .#{{ machine }} "${@:2}"
  QEMU_NET_OPTS="hostfwd=tcp::8080-:80,hostfwd=tcp::8081-:443,hostfwd=tcp::2222-:22" ./result/bin/run-*-vm

@update-inputs *_:
  @git reset flake.lock
  @git restore flake.lock
  nix eval {{nix_eval_opts}} --file flake.nix --apply 'x: builtins.attrNames x.inputs' --json \
    | { printf "%s\n" --commit-lock-file; jq '.[]' -r | grep -vxF "self" ||:; } \
    | gum choose --no-limit --header "Choose extra arguments:" \
    | tee >(xargs -d'\n' echo + nix flake update "$@" >&2) \
    | xargs -d'\n' nix flake update "$@"

@repl $machine=`just _a_machine` *_:
  set -v; NIX_NO_NOM=1 nixos-rebuild --flake .#"$machine" repl "${@:2}"

@eval $machine=`just _a_machine` $attrpath="system.build.toplevel.outPath" *_:
  set -v; nix eval {{nix_eval_opts}} ".#nixosConfigurations.\"$machine\".config.$attrpath" --show-trace "${@:3}"

@eval-vm $machine=`just _a_machine` $attrpath="system.build.toplevel.outPath" *_:
  just eval "$machine" "virtualisation.vmVariant.$attrpath" "${@:3}"


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
