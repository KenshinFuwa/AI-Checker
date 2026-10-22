#!/usr/bin/env python3
"""Verify a downloaded release DMG against the matching shasum -a 256 record.

Byte integrity only: not identity verification, notarization, or Gatekeeper.
No network, execution or filesystem writes.
"""
import hashlib
import pathlib
import re
import sys


def verify(dmg_path: pathlib.Path, checksum_path: pathlib.Path) -> str:
    if dmg_path.suffix.lower() != ".dmg":
        raise ValueError("expected a .dmg file")
    for path in (dmg_path, checksum_path):
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"input is not a regular non-symlink file: {path}")
    if checksum_path.stat().st_size > 512:
        raise ValueError("checksum record exceeds size limit")
    record = checksum_path.read_bytes()
    # Exactly one ASCII sha256sum-style line; no external paths or control chars.
    m = re.fullmatch(rb"([0-9a-fA-F]{64})  ([A-Za-z0-9][A-Za-z0-9._-]*\.dmg)\n?", record)
    if m is None:
        raise ValueError("malformed .sha256 record; expected '<64 hex>  <name>.dmg'")
    try:
        listed_name = m.group(2).decode("ascii")
    except UnicodeDecodeError as exc:
        raise ValueError("non-ASCII checksum filename") from exc
    if listed_name != dmg_path.name:
        raise ValueError("checksum lists a different DMG filename")
    expected = m.group(1).decode("ascii").lower()
    digest = hashlib.sha256()
    with dmg_path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != expected:
        raise ValueError("SHA-256 MISMATCH; do not use the DMG")
    return expected


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("USAGE: verify-release-checksum.py /absolute/file.dmg /absolute/file.dmg.sha256", file=sys.stderr)
        return 2
    try:
        if not pathlib.Path(argv[1]).is_absolute() or not pathlib.Path(argv[2]).is_absolute():
            raise ValueError("both paths must be absolute")
        result = verify(pathlib.Path(argv[1]), pathlib.Path(argv[2]))
    except (ValueError, OSError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(f"PASS: SHA-256 matches {result} (integrity only; notarization NOT verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
