#!/usr/bin/env python3

import argparse
import re
import shutil
from pathlib import Path


# Syntactic dotted-name expression:
# ident(.ident)*
DOTTED_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$")

# Match double-quoted strings
DOUBLE_QUOTED_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def is_valid_dotted_name(s: str) -> bool:
    return DOTTED_NAME_RE.fullmatch(s) is not None


def patch_stf_text(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        inner = match.group(1)

        if "\\" in inner:
            return match.group(0)

        if is_valid_dotted_name(inner):
            return inner

        return match.group(0)

    return DOUBLE_QUOTED_RE.sub(repl, text)


def make_output_dir(src_dir: Path) -> Path:
    return src_dir.parent / f"{src_dir.name}_patched"


def patch_files(directory: Path) -> None:
    for stf_path in directory.rglob("*.stf"):
        original = stf_path.read_text(encoding="utf-8")
        patched = patch_stf_text(original)
        stf_path.write_text(patched, encoding="utf-8")


def patch_directory(src_dir: Path, dst_dir: Path) -> None:
    if dst_dir.exists():
        raise FileExistsError(f"Destination already exists: {dst_dir}")

    shutil.copytree(src_dir, dst_dir)
    patch_files(dst_dir)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch .stf files by unquoting syntactically valid dotted names."
    )
    parser.add_argument("directory", help="Source directory")
    parser.add_argument(
        "--output",
        help="Output directory (default: <directory>_patched)",
        default=None,
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Patch files in place instead of copying",
    )

    args = parser.parse_args()

    src_dir = Path(args.directory).resolve()
    if not src_dir.is_dir():
        raise NotADirectoryError(f"Not a directory: {src_dir}")

    if args.in_place and args.output:
        raise ValueError("--output and --in-place cannot be used together")

    if args.in_place:
        patch_files(src_dir)
        print(f"Patched files in-place in: {src_dir}")
        return

    dst_dir = Path(args.output).resolve() if args.output else make_output_dir(src_dir)
    patch_directory(src_dir, dst_dir)

    print(f"Patched copy created at: {dst_dir}")


if __name__ == "__main__":
    main()
