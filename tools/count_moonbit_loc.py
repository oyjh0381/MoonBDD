#!/usr/bin/env python3
"""Report reproducible MoonBit source line counts for OSC review."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MINIMUM_EFFECTIVE_LOC = 4_000


def main() -> int:
    excluded = {"_build", ".mooncakes", ".git", ".scratch", "target"}
    files = sorted(
        path
        for path in ROOT.rglob("*.mbt")
        if not excluded.intersection(path.relative_to(ROOT).parts)
    )
    physical = 0
    nonblank = 0
    effective = 0
    for path in files:
        for line in path.read_text(encoding="utf-8").splitlines():
            physical += 1
            stripped = line.strip()
            if not stripped:
                continue
            nonblank += 1
            if stripped.startswith(("///", "//")):
                continue
            effective += 1
    print(
        f"MoonBit LOC: files={len(files)} physical={physical} "
        f"nonblank={nonblank} effective_noncomment={effective} "
        f"minimum={MINIMUM_EFFECTIVE_LOC}"
    )
    if effective < MINIMUM_EFFECTIVE_LOC:
        print("MoonBit LOC check failed: effective source is below the OSC reference floor")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
