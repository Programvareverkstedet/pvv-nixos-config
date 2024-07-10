#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages(ps: with ps; [ beautifulsoup4 requests ])" nix-prefetch-git

import os
from pathlib import Path
import re
import subprocess
from collections import defaultdict
from pprint import pprint
from dataclasses import dataclass
from functools import cache
import json

import bs4
import requests


BASE_WEB_URL = "https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/extensions"
BASE_GIT_URL = "https://gerrit.wikimedia.org/r/mediawiki/extensions/"


@dataclass
class PluginMetadata:
    project_name: str
    tracking_branch: str | None
    commit: str
    hash_: str


@cache
def get_package_listing_path():
    return Path(__file__).parent / "default.nix"


@cache
def get_global_tracking_branch() -> str:
    with open(get_package_listing_path()) as file:
        file_content = file.read()
    return re.search(r'\btracking-branch\b \? "([^"]+?)"', file_content).group(1)


def get_metadata(package_expression: str) -> PluginMetadata | None:
    project_name_search = re.search(r'\bname\b = "([^"]+?)";', package_expression)
    tracking_branch_search = re.search(r'\btracking-branch\b = "([^"]+?)";', package_expression)
    commit_search = re.search(r'\bcommit\b = "([^"]*?)";', package_expression)
    hash_search = re.search(r'\bhash\b = "([^"]*?)";', package_expression)

    if project_name_search is None:
        print("Could not find project name in package:")
        print(package_expression)
        return None

    tracking_branch = None;
    if tracking_branch_search is not None:
        tracking_branch = tracking_branch_search.group(1)

    if commit_search is None:
        print("Could not find commit in package:")
        print(package_expression)
        return None

    if hash_search is None:
        print("Could not find hash in package:")
        print(package_expression)
        return None

    return PluginMetadata(
        commit = commit_search.group(1),
        tracking_branch = tracking_branch,
        project_name = project_name_search.group(1),
        hash_ = hash_search.group(1),
    )


def update_metadata(package_expression: str, metadata: PluginMetadata) -> str:
    result = package_expression
    result = re.sub(r'\bcommit\b = "[^"]*";', f'commit = "{metadata.commit}";', result)
    result = re.sub(r'\bhash\b = "[^"]*";', f'hash = "{metadata.hash_}";', result)
    return result


def get_newest_commit(project_name: str, tracking_branch: str) -> str:
    content = requests.get(f"{BASE_WEB_URL}/{project_name}/+log/refs/heads/{tracking_branch}/").text
    soup = bs4.BeautifulSoup(content, features="html.parser")
    try:
        a = soup.find('li').findChild('a')
        commit_sha = a['href'].split('/')[-1]
    except AttributeError:
        print(f"ERROR: Could not parse page for {project_name}:")
        print(soup.prettify())
        exit(1)
    return commit_sha


def get_nix_hash(url: str, commit: str) -> str:
    out, err = subprocess.Popen(
        ["nix-prefetch-git", "--url", url, "--rev", commit, "--fetch-submodules", "--quiet"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    ).communicate()

    return json.loads(out.decode().strip())['hash']


def update_expression(package_expression: str) -> str:
    old_metadata = get_metadata(package_expression)
    if old_metadata is None:
        print("ERROR: could not find metadata for expression:")
        print(package_expression)
        return

    if old_metadata.commit == "":
        old_metadata.commit = "<none>"
    if old_metadata.hash_ == "":
        old_metadata.hash_ = "<none>"

    tracking_branch = old_metadata.tracking_branch
    if tracking_branch is None:
        tracking_branch = get_global_tracking_branch()

    new_commit = get_newest_commit(old_metadata.project_name, tracking_branch)
    new_hash = get_nix_hash(f"{BASE_GIT_URL}/{old_metadata.project_name}", new_commit)
    if new_hash is None or new_hash == "":
        print(f"ERROR: could not fetch hash for {old_metadata.project_name}")
        exit(1)

    print(f"Updating {old_metadata.project_name}[{tracking_branch}]: {old_metadata.commit} -> {new_commit}")

    new_metadata = PluginMetadata(
        project_name = old_metadata.project_name,
        tracking_branch = old_metadata.tracking_branch,
        commit = new_commit,
        hash_ = new_hash,
    )

    return update_metadata(package_expression, new_metadata)


def update_all_expressions_in_default_nix() -> None:
    with open(get_package_listing_path()) as file:
        file_content = file.read()

    new_file_content = re.sub(
        r"\(mw-ext\s*\{(?:.|\n)+?\}\)",
        lambda m: update_expression(m.group(0)),
        file_content,
        flags = re.MULTILINE,
    )

    with open(get_package_listing_path(), 'w') as file:
        file.write(new_file_content)


if __name__ == "__main__":
    update_all_expressions_in_default_nix()
