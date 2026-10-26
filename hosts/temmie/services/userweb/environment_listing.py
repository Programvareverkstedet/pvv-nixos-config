import argparse
import importlib.metadata
import json
import os
import platform
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

# TODO: in theory, we could add a whole bunch of more metadata about these packages,
#       pulled from the eval-time metadata in nixpkgs. Leaving it for now though.


class Package(NamedTuple):
    version: str
    # I.e. executables or modules
    package_items: list[str]


def add(
    packages: dict[str, Package],
    package: str,
    version: str,
    name: str,
) -> None:
    packages.setdefault(
        package,
        Package(version, []),
    ).package_items.append(name)


def parse_store_path(store_dir: Path, path: Path) -> tuple[str, str]:
    store_name = Path(os.path.realpath(path)).relative_to(store_dir).parts[0]
    name = store_name.split("-", 1)[1]
    match = re.compile(r"^(.*?)-([^a-zA-Z].*)$").match(name)
    package, version = (
        (match[1], re.compile(r"-[a-z]+$").sub("", match[2])) if match else (name, "")
    )
    return re.compile(r"^python[0-9.]+-").sub("", package), version


def render_as_json_file(
    path: Path,
    packages: dict[str, Package],
    key: str,
) -> None:
    with open(path, "w") as file:
        json.dump(
            {
                name: {
                    "version": package.version,
                    key: sorted(package.package_items, key=str.lower),
                }
                for name, package in sorted(
                    packages.items(), key=lambda kv: kv[0].lower()
                )
            },
            file,
            indent=2,
        )
        file.write("\n")


def list_executables(store_dir: Path, fhs_env: Path) -> dict[str, Package]:
    packages = {}
    seen = set()
    for directory in [fhs_env / "bin", fhs_env / "sbin"]:
        assert directory.is_dir()
        for executable in directory.iterdir():
            if (
                executable.name in seen
                or executable.name.startswith(".")
                or not executable.is_file()
                or not os.access(executable, os.X_OK)
            ):
                continue
            seen.add(executable.name)
            add(packages, *parse_store_path(store_dir, executable), executable.name)
    return packages


def list_libraries(store_dir: Path, fhs_env: Path) -> dict[str, Package]:
    packages = {}
    directory = fhs_env / "lib"
    assert directory.is_dir()
    for library in directory.iterdir():
        if (
            not re.match(r"^lib.*\.so(\.[0-9]+)*$", library.name)
            or not library.is_file()
        ):
            continue
        add(packages, *parse_store_path(store_dir, library), library.name)
    return packages


def list_python_modules() -> dict[str, Package]:
    def is_public(name: str) -> bool:
        return name.isidentifier() and not name.startswith("_")

    packages = {
        "python3": Package(
            platform.python_version(),
            [name for name in sys.stdlib_module_names if is_public(name)],
        ),
    }

    for name, dists in importlib.metadata.packages_distributions().items():
        if name in sys.stdlib_module_names or not is_public(name):
            continue
        add(packages, dists[0], importlib.metadata.version(dists[0]), name)

    return packages


def list_php_modules(store_dir: Path, php: Path) -> dict[str, Package]:
    def run_php(*args: str) -> str:
        return subprocess.run(
            [php, *args],
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    version, *compiled_in = run_php(
        "-n",
        "-r",
        "echo PHP_VERSION, PHP_EOL, implode(PHP_EOL, get_loaded_extensions());",
    ).splitlines()
    packages = {"php": Package(version, compiled_in)}

    for ini_file in run_php("-r", "echo php_ini_scanned_files();").split(","):
        for match in re.finditer(
            r"^extension=(.+)$",
            Path(ini_file.strip()).read_text(),
            re.MULTILINE,
        ):
            path = Path(match[1])
            # NOTE: skip builtin extensions, listed under the `php` package.
            if path.stem.lower() not in map(str.lower, compiled_in):
                add(
                    packages,
                    *parse_store_path(store_dir, path),
                    path.stem,
                )
    return packages


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--store-dir", type=Path, required=True)
    parser.add_argument("--fhs-env", type=Path, required=True)
    parser.add_argument("--php", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    render_as_json_file(
        args.out / "executables.json",
        list_executables(args.store_dir, args.fhs_env),
        key="executables",
    )
    render_as_json_file(
        args.out / "libraries.json",
        list_libraries(args.store_dir, args.fhs_env),
        key="libraries",
    )
    render_as_json_file(
        args.out / "python3-modules.json",
        list_python_modules(),
        key="modules",
    )
    render_as_json_file(
        args.out / "php-modules.json",
        list_php_modules(args.store_dir, args.php),
        key="modules",
    )


if __name__ == "__main__":
    main()
