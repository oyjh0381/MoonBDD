#!/usr/bin/env python3
"""Black-box smoke tests for the Native CLI process contract."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
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

    with tempfile.TemporaryDirectory() as directory:
        expression_file = Path(directory) / "constraint.bdd"
        expression_file.write_text("a <-> b", encoding="utf-8")
        file_count = run("count", "a,b", f"@{expression_file}")
        require(file_count.returncode == 0, file_count.stderr)
        require(file_count.stdout == "2\n", file_count.stdout)

    witness = run("sat-one", "a,b", "a ^ b")
    require(witness.returncode == 0, witness.stderr)
    values = json.loads(witness.stdout)
    require(values["a"] != values["b"], witness.stdout)

    reach = run("reach")
    require(reach.returncode == 0, reach.stderr)
    require(json.loads(reach.stdout)["invariant_holds"] is True, reach.stdout)

    malformed = run("count", "a", "a & )")
    require(malformed.returncode == 3, malformed.stderr)
    malformed_error = json.loads(malformed.stderr.removeprefix("MOONBDD_ERROR "))
    require(malformed_error["code"] == "parse", malformed.stderr)

    invalid = run("count", "true", "true")
    require(invalid.returncode == 4, invalid.stderr)
    invalid_error = json.loads(invalid.stderr.removeprefix("MOONBDD_ERROR "))
    require(invalid_error["code"] == "invalid_input", invalid.stderr)

    missing = run("count", "a", "@definitely-missing-expression.bdd")
    require(missing.returncode == 8, missing.stderr)
    missing_error = json.loads(missing.stderr.removeprefix("MOONBDD_ERROR "))
    require(missing_error["code"] == "io", missing.stderr)

    usage = run("unknown")
    require(usage.returncode == 2, usage.stderr)
    usage_error = json.loads(usage.stderr.removeprefix("MOONBDD_ERROR "))
    require(usage_error["code"] == "usage", usage.stderr)
    print("CLI contract: 10 scenarios passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
