#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages(ps: with ps; [ beautifulsoup4 requests ])" nix-prefetch-git

import os
from pathlib import Path
import re
import subprocess
from collections import defaultdict
from pprint import pprint
from dataclasses import dataclass
import json

import bs4
import requests

BASE_WEB_URL = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions"
BASE_GIT_URL = "https://gerrit.wikimedia.org/r/mediawiki/extensions/"

@dataclass
class PluginMetadata:
    project_name: str
    tracking_branch: str
    commit: str


def get_metadata(file_content: str) -> dict[str,str] | None:
    commit_search = re.search(f'commit = "([^"]*?)";', file_content)
    tracking_branch_search = re.search(f'tracking-branch = "([^"]+?)";', file_content)
    project_name_search = re.search(f'project-name = "([^"]+?)";', file_content)
    if commit_search is None:
        print("Could not find commit in file:")
        print(file_content)
        return None
    if tracking_branch_search is None:
        print("Could not find tracking branch in file:")
        print(file_content)
        return None
    if project_name_search is None:
        print("Could not find project name in file:")
        print(file_content)
        return None
    return PluginMetadata(
        commit = commit_search.group(1),
        tracking_branch = tracking_branch_search.group(1),
        project_name = project_name_search.group(1),
    )


def get_newest_commit(project_name: str, tracking_branch: str) -> str:
    content = requests.get(f"{BASE_WEB_URL}/{project_name}/+log/refs/heads/{tracking_branch}/").text
    soup = bs4.BeautifulSoup(content, features="html.parser")
    a = soup.find('li').findChild('a')
    commit_sha = a['href'].split('/')[-1]
    return commit_sha


def get_nix_hash(url: str, commit: str) -> str:
    out, err = subprocess.Popen(
        ["nix-prefetch-git", "--url", url, "--rev", commit, "--fetch-submodules", "--quiet"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    ).communicate()

    return json.loads(out.decode().strip())['hash']


def set_commit_and_hash(file_content: str, commit: str, sha256: str) -> str:
    result = file_content
    result = re.sub('commit = "[^"]*";', f'commit = "{commit}";', result)
    result = re.sub('hash = "[^"]*";', f'hash = "{sha256}";', result)
    return result

def update(package_file: Path) -> None:
    with open(package_file) as file:
        file_content = file.read()

    metadata = get_metadata(file_content)
    if metadata is None:
        print(f"ERROR: could not find metadata for {package_file}")
        return
    if metadata.commit == "":
        metadata.commit = "<none>"

    new_commit = get_newest_commit(metadata.project_name, metadata.tracking_branch)
    new_hash = get_nix_hash(f"{BASE_GIT_URL}/{metadata.project_name}", new_commit)
    if new_hash is None or new_hash == "":
        print(f"ERROR: could not fetch hash for {metadata.project_name}")
        exit(1)

    print(f"Updating {metadata.project_name}: {metadata.commit} -> {new_commit}")

    new_file_content = set_commit_and_hash(file_content, new_commit, new_hash)

    with open(package_file, 'w') as file:
        file.write(new_file_content)


if __name__ == "__main__":
    for direntry in os.scandir(Path(__file__).parent):
        if direntry.is_dir():
            package_file = Path(direntry) / "default.nix"
            assert package_file.is_file()
            update(package_file)
