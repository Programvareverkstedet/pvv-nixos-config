import argparse
import hashlib
import os
import requests
import subprocess
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Generate SSH keys for Gitea repositories and add them as secrets")
    parser.add_argument("--org", required=True, type=str, help="The organization to generate keys for")
    parser.add_argument("--token-path", metavar='PATH', required=True, type=Path, help="Path to a file containing the Gitea API token")
    parser.add_argument("--api-url", metavar='URL', type=str, help="The URL of the Gitea API", default="https://git.pvv.ntnu.no/api/v1")
    parser.add_argument("--key-dir", metavar='PATH', type=Path, help="The directory to store the generated keys in", default="/run/gitea-web-secret-provider")
    parser.add_argument("--authorized-keys-path", metavar='PATH', type=Path, help="The path to the resulting authorized_keys file", default="/etc/ssh/authorized_keys.d/gitea-web-secret-provider")
    parser.add_argument("--rrsync-script", metavar='PATH', type=Path, help="The path to a rrsync script, taking the destination path as its single argument")
    parser.add_argument("--web-dir", metavar='PATH', type=Path, help="The directory to sync the repositories to", default="/var/www")
    parser.add_argument("--force", action="store_true", help="Overwrite existing keys")
    return parser.parse_args()


def add_secret(args: argparse.Namespace, token: str, repo: str, name: str, secret: str):
    result = requests.put(
        f"{args.api_url}/repos/{args.org}/{repo}/actions/secrets/{name}",
        json = { 'data': secret },
        headers = { 'Authorization': 'token ' + token },
    )
    if result.status_code not in (201, 204):
        raise Exception(f"Failed to add secret: {result.json()}")


def get_org_repo_list(args: argparse.Namespace, token: str):
    result = requests.get(
        f"{args.api_url}/orgs/{args.org}/repos",
        headers = { 'Authorization': 'token ' + token },
    )
    return [repo["name"] for repo in result.json()]


def generate_ssh_key(args: argparse.Namespace, repository: str):
    keyname = hashlib.sha256(args.org.encode() + repository.encode()).hexdigest()
    key_path = args.key_dir / keyname
    if not key_path.is_file() or args.force:
        subprocess.run(
            [
                "ssh-keygen",
                *("-t", "ed25519"),
                *("-f", key_path),
                *("-N", ""),
                *("-C", f"{args.org}/{repository}"),
            ],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        print(f"Generated SSH key for `{args.org}/{repository}`")

    with open(key_path, "r") as f:
        private_key = f.read()

    pub_key_path = args.key_dir / (keyname + '.pub')
    with open(pub_key_path, "r") as f:
        public_key = f.read()

    return private_key, public_key


SSH_OPTS = ",".join([
    "restrict",
    "no-agent-forwarding",
    "no-port-forwarding",
    "no-pty",
    "no-X11-forwarding",
])


def generate_authorized_keys(args: argparse.Namespace, repo_public_keys: list[tuple[str, str]]):
    lines = []
    for repo, public_key in repo_public_keys:
        command = f"{args.rrsync_script} {args.web_dir}/{args.org}/{repo}"
        lines.append(f'command="{command}",{SSH_OPTS} {public_key}')

    with open(args.authorized_keys_path, "w") as f:
        f.writelines(lines)


def main():
    args = parse_args()

    with open(args.token_path, "r") as f:
        token = f.read().strip()

    os.makedirs(args.key_dir, 0o700, exist_ok=True)
    os.makedirs(args.authorized_keys_path.parent, 0o700, exist_ok=True)

    repos = get_org_repo_list(args, token)
    print(f'Found {len(repos)} repositories in `{args.org}`')

    repo_public_keys = []
    for repo in repos:
        print(f"Locating key for `{args.org}/{repo}`")
        private_key, public_key = generate_ssh_key(args, repo)
        add_secret(args, token, repo, "WEB_SYNC_SSH_KEY", private_key)
        repo_public_keys.append((repo, public_key))

    generate_authorized_keys(args, repo_public_keys)
    print(f"Wrote authorized_keys file to `{args.authorized_keys_path}`")


if __name__ == "__main__":
    main()
