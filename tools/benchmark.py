#!/usr/bin/env python3
"""Reproducible ROBDD variable-order performance baseline."""

from __future__ import annotations

import json
import statistics
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPRESSION = " & ".join(f"(a{i} <-> b{i})" for i in range(1, 7))
GOOD_ORDER = ",".join(name for i in range(1, 7) for name in (f"a{i}", f"b{i}"))
BAD_ORDER = ",".join([*(f"a{i}" for i in range(1, 7)), *(f"b{i}" for i in range(1, 7))])


def measure(order: str, repetitions: int = 3) -> dict[str, object]:
    durations: list[float] = []
    payload: dict[str, object] | None = None
    for _ in range(repetitions):
        started = time.perf_counter()
        run = subprocess.run(
            ["moon", "run", "cmd/moonbdd", "--target", "native", "--", "stats", order, EXPRESSION],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        durations.append((time.perf_counter() - started) * 1000.0)
        if run.returncode != 0:
            raise RuntimeError(run.stderr)
        current = json.loads(run.stdout)
        if payload is not None and current != payload:
            raise AssertionError("stats changed between deterministic repetitions")
        payload = current
    assert payload is not None
    return {"stats": payload, "median_ms": round(statistics.median(durations), 3)}


def main() -> int:
    result = {
        "case": "six-pair Boolean equality",
        "repetitions": 3,
        "interleaved": measure(GOOD_ORDER),
        "grouped": measure(BAD_ORDER),
    }
    good = int(result["interleaved"]["stats"]["reachable_nodes"])
    bad = int(result["grouped"]["stats"]["reachable_nodes"])
    if bad <= good:
        raise AssertionError(f"expected grouped order to exceed interleaved: {bad} <= {good}")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
