# Secret management and `sops-nix`

Nix config is love, nix config is life, and publishing said config to the
internet is not only a good deed and kinda cool, but also encourages properly
secured configuration as opposed to [security through obscurity](https://en.wikipedia.org/wiki/Security_through_obscurity).
That being said, there are some details of the config that we really shouldn't
share with the general public. In particular, there are so-called *secrets*, that is
API keys, passwords, tokens, cookie secrets, salts, peppers and jalapenos that we'd
rather keep to ourselves. However, it is not entirely trivial to do so in the NixOS config.
For one, we'd have to keep these secrets out of the public git repo somehow, and secondly
everything that is configured via nix ends up as world readable files (i.e. any user on the
system can read the file) in `/nix/store`.

In order to solve this, we use a NixOS module called [`sops-nix`](https://github.com/Mic92/sops-nix)
which uses a technology called [`sops`](https://github.com/getsops/sops) behind the scenes.
The idea is simple: we encrypt these secrets with a bunch of different keys and store the
encrypted files in the git repo. First of all, we encrypt the secrets a bunch of time with
PVV maintenance member's keys, so that we can decrypt and edit the contents. Secondly, we
encrypt the secrets with the [host keys]() of the NixOS machines, so that they can decrypt
the secrets. The secrets will be decrypted and stored in a well-known location (usually `/run/secrets`)
so that they do not end up in the nix store, and are not world readable.

This way, we can both keep the secrets in the git repository and let multiple people edit them,
but also ensure that they don't end up in the wrong hands.

## Adding a new machine

In order to add a new machine to the nix-sops setup, you should do the following:

```console
# Create host keys (if they don't already exist)
ssh-keygen -A -b 4096

# Derive an age-key from the public host key
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'

# Register the age key in .sops.yaml
vim .sops.yaml
```

The contents of `.sops.yaml` should look like this:

```yaml
keys:
  # Users
  ...

  # Hosts
  ...
  - &host_<machine_name> <public_age_key>

creation_rules:
  ...

  - path_regex: secrets/<machine_name>/[^/]+\.yaml$
    key_groups:
    - age:
      - *host_<machine_name>
      - ... user keys
    - pgp:
      - ... user keys
```

> [!NOTE]
> Take care that all the keys in the `age` and `pgp` sections are prefixed
> with a `-`, or else sops might try to encrypt the secrets in a way where
> you need both keys present to decrypt the content. Also, it tends to throw
> interesting errors when it fails to do so.

```console
# While cd-ed into the repository, run this to get a shell with the `sops` tool present
nix-shell
```

Now you should also be able to edit secrets for this machine by running:

```
sops secrets/<machine_name>/<machine_name>.yaml
```

## Adding a user

Adding a user is quite similar to adding a new machine.
This guide assumes you have already set up SSH keys.

```
# Derive an age-key from your key
# (edit the path to the key if it is named something else)
nix-shell -p ssh-to-age --run 'cat ~/.ssh/id_ed25519.pub | ssh-to-age'

# Register the age key in .sops.yaml
vim .sops.yaml
```

The contents of `.sops.yaml` should look like this:

```yaml
keys:
  # Users
  ...
  - &user_<user_name> <public_age_key>

  # Hosts
  ...

creation_rules:
  ...

  # Do this for all the machines you are planning to edit
  # (or just do it for all machines)
  - path_regex: secrets/<machine_name>/[^/]+\.yaml$
    key_groups:
    - age:
      - *host_<machine_name>
      - ... user keys
      - *host_<user_name>
    - pgp:
      - ... user keys
```

Now that sops is properly configured to recognize the key, you need someone
who already has access to decrypt all the secrets and re-encrypt them with your
key. At this point, you should probably [open a PR](https://docs.gitea.com/usage/issues-prs/pull-request)
and ask someone in PVV maintenance if they can checkout the PR branch, run the following
command and push the diff back into the PR (and maybe even ask them to merge if you're feeling
particularly needy).

```console
sops updatekeys secrets/*/*.yaml
```

## Updating keys

> [!NOTE]
> At some point, we found this flag called `sops -r` that seemed to be described to do what
> `sops updatekeys` does, do not be fooled. This only rotates the "inner key" for those who
> already have the secrets encrypted with their key.

Updating keys is done with this command:

```console
sops updatekeys secrets/*/*.yaml
```

However, there is a small catch. [oysteikt](https://git.pvv.ntnu.no/oysteikt) has kinda been
getting gray hairs lately, and refuses to use modern technology - he is still stuck using GPG.
This means that to be able to re-encrypt the sops secrets, you will need to have a gpg keychain
with his latest public key available. The key has an expiry date, so if he forgets to update it,
you should send him and angry email and tag him a bunch of times in a gitea issue. If the key
is up to date, you can do the following:

```console
# Fetch gpg (unless you have it already)
nix shell nixpkgs#gnupg

# Import oysteikts key to the gpg keychain
gpg --import ./keys/oysteikt.pub
```

Now you should be able to run the `sops updatekeys` command again.
