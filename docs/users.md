# User management

Due to some complications with how NixOS creates users compared to how we used to
create users with the salt-based setup, the NixOS machine users are created and
managed separately. We tend to create users on-demand, whenever someone in PVV
maintenance want to work on the NixOS machines.

## Setting up a new user

You can find the files for the existing users, and thereby examples of user files
in the [`users`](../users) directory. When creating a new file here, you should name it
`your-username.nix`, and add *at least* the following contents:

```nix
{ pkgs, ... }:
{
  users.users."<username>" = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # In case you wanna use sudo (you probably do)
      "nix-builder-users" # Arbitrary access to write to the nix store
    ];

    # Any packages you frequently use to manage servers go here.
    # Please don't pull gigantonormous packages here unless you
    # absolutely need them, and remember that any package can be
    # pulled via nix-shell if you only use it once in a blue moon.
    packages = with pkgs; [
      bottom
      eza
    ];

    # Not strictly needed, but we recommend adding your public SSH
    # key here. If it is not present, you will have to log into the
    # machine as 'root' before setting your password for every NixOS
    # machine you have not logged into yet.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjiQ0wg4lpC7YBMAAHoGmgwqHOBi+EUz5mmCymGlIyT my-key"
    ];
  };
}
```

The file will be picked up automatically, so creating the file and adding the
contents should be enough to get you registered. You should
[open a PR](https://docs.gitea.com/usage/issues-prs/pull-request) with the new
code so the machines will be rebuilt with your user present.

See also [Secret Management](./secret-management.md) for how to add your keys to the
system that lets us add secrets (API keys, password, etc.) to the NixOS config.
