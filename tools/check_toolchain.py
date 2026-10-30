#!/usr/bin/env python3
"""Fail early if moonc is older than the project's validated minimum."""
import re
import subprocess
import sys

result = subprocess.run(["moon", "version", "--all"], text=True, capture_output=True, check=True)
print(result.stdout, end="")
match = re.search(r"moonc v?(\d+)\.(\d+)\.(\d+)", result.stdout)
if not match or tuple(map(int, match.groups())) < (0, 10, 16):
    sys.exit("MoonBDD requires moonc >= 0.10.16; validated toolchain: moon 0.1.20261016")
