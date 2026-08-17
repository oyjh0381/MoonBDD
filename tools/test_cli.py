#!/usr/bin/env python3
"""Black-box smoke tests for the Native CLI process contract."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(*arguments: str, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["moon", "run", "cmd/moonbdd", "--target", "native", "--", *arguments],
        cwd=ROOT,
        input=stdin,
        text=True,
        capture_output=True,
        check=False,
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    version = run("version")
    require(version.returncode == 0, version.stderr)
    require(version.stdout == "MoonBDD 0.1.0 (artifact schema 1)\n", version.stdout)

    stats = run("stats", "a,b", "a & b")
    require(stats.returncode == 0, stats.stderr)
    require(json.loads(stats.stdout)["model_count"] == "1", stats.stdout)

    count = run("count", "a,b", "-", stdin="a | b")
    require(count.returncode == 0, count.stderr)
    require(count.stdout == "3\n", count.stdout)

    witness = run("sat-one", "a,b", "a ^ b")
    require(witness.returncode == 0, witness.stderr)
    values = json.loads(witness.stdout)
    require(values["a"] != values["b"], witness.stdout)

    reach = run("reach")
    require(reach.returncode == 0, reach.stderr)
    require(json.loads(reach.stdout)["invariant_holds"] is True, reach.stdout)

    malformed = run("count", "a", "a & )")
    require(malformed.returncode != 0, "malformed input unexpectedly succeeded")
    require(malformed.stderr.startswith("MOONBDD_ERROR:"), malformed.stderr)
    print("CLI contract: 6 scenarios passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
