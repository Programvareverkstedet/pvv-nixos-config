#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages(ps: with ps; [ beautifulsoup4 requests ])"

import os
from pathlib import Path
import re
import subprocess
from collections import defaultdict
from pprint import pprint

import bs4
import requests

BASE_URL = "https://extdist.wmflabs.org/dist/extensions"

def fetch_plugin_list(skip_master=True) -> dict[str, list[str]]:
    content = requests.get(BASE_URL).text
    soup = bs4.BeautifulSoup(content, features="html.parser")
    result = defaultdict(list)
    for a in soup.find_all('a'):
        if skip_master and 'master' in a.text:
            continue
        split = a.text.split('-')
        result[split[0]].append(a.text)
    return result

def update(package_file: Path, plugin_list: dict[str, list[str]]) -> None:
    assert package_file.is_file()
    with open(package_file) as file:
        content = file.read()

    tarball = re.search(f'url = "{BASE_URL}/(.+\.tar\.gz)";', content).group(1)
    split = tarball.split('-')
    updated_tarball = plugin_list[split[0]][-1]

    _hash = re.search(f'hash = "(.+?)";', content).group(1)

    out, err = subprocess.Popen(
        ["nix-prefetch-url", "--unpack", "--type", "sha256", f"{BASE_URL}/{updated_tarball}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    ).communicate()
    out, err = subprocess.Popen(
        ["nix", "hash", "to-sri", "--type", "sha256", out.decode().strip()],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    ).communicate()

    updated_hash = out.decode().strip()

    if tarball == updated_tarball and _hash == updated_hash:
        return

    print(f"Updating: {tarball} ({_hash[7:14]}) -> {updated_tarball} ({updated_hash[7:14]})")

    updated_text = re.sub(f'url = "{BASE_URL}/.+?\.tar\.gz";', f'url = "{BASE_URL}/{updated_tarball}";', content)
    updated_text = re.sub('hash = ".+";', f'hash = "{updated_hash}";', updated_text)
    with open(package_file, 'w') as file:
        file.write(updated_text)

if __name__ == "__main__":
    plugin_list = fetch_plugin_list()

    for direntry in os.scandir(Path(__file__).parent):
        if direntry.is_dir():
            update(Path(direntry) / "default.nix", plugin_list)
