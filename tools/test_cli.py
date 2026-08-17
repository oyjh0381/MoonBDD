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

    table = run("truth-table", "a,b", "a ^ b", "3")
    require(table.returncode == 0, table.stderr)
    table_payload = json.loads(table.stdout)
    require(table_payload["complete"] is False, table.stdout)
    require(len(table_payload["rows"]) == 3, table.stdout)

    cubes = run("cubes", "a,b,c", "(a & b) | (!a & c)", "8")
    require(cubes.returncode == 0, cubes.stderr)
    cubes_payload = json.loads(cubes.stdout)
    require(cubes_payload["complete"] is True, cubes.stdout)
    require(
        cubes_payload["cubes"]
        == [{"a": False, "c": True}, {"a": True, "b": True}],
        cubes.stdout,
    )

    backbone = run("backbone", "a,b,c", "a & !b")
    require(backbone.returncode == 0, backbone.stderr)
    require(json.loads(backbone.stdout) == {"a": True, "b": False}, backbone.stdout)

    diagnosis = run(
        "diagnose",
        "a,b,c",
        "enable-a=a;a-needs-b=!a | b;disable-b=!b;irrelevant=c | !c",
    )
    require(diagnosis.returncode == 0, diagnosis.stderr)
    diagnosis_payload = json.loads(diagnosis.stdout)
    require(diagnosis_payload["satisfiable"] is False, diagnosis.stdout)
    require(
        diagnosis_payload["minimal_conflict"]
        == ["enable-a", "a-needs-b", "disable-b"],
        diagnosis.stdout,
    )

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
    print("CLI contract: 14 scenarios passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
