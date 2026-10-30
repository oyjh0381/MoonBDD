#!/usr/bin/env python3
"""Read-only submission preflight. Findings contain locations, never values.

Heuristics cannot certify that no customer data or proprietary source exists.
Review findings and provenance manually; this tool never rewrites Git history.
"""
from __future__ import annotations

import argparse
import ipaddress
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "private_key": re.compile(rb"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"),
    "github_token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{40,255})\b"),
    "aws_access_key": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "credential_assignment": re.compile(
        rb"(?i)\b(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]\s*[\"'][^\"'\r\n]{12,}[\"']"
    ),
    "contact_email": re.compile(
        rb"(?<![\w./+\-])[A-Za-z0-9][A-Za-z0-9._+\-]*@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}(?![\w.])"
    ),
}
IPV4 = re.compile(rb"(?<![\w.])(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?![\w.])")
# RFC 1918 networks, expressed as integers so the scanner needs no self-exemption.
INTERNAL = tuple(ipaddress.ip_network(net) for net in (
    (10 << 24, 8), ((172 << 24) | (16 << 16), 12), ((192 << 24) | (168 << 16), 16),
))
LOCAL_MATERIAL = re.compile(r"申报书|审查报告|审核报告|辅助报告|汇总报告|(?:^|/)[^/]*(?:REPORT|REVIEW)[^/]*\.(?:md|json|txt|pdf|docx)$", re.I)


def git(*args: str) -> bytes:
    return subprocess.run(
        ["git", "-c", f"safe.directory={ROOT.as_posix()}", *args], cwd=ROOT,
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    ).stdout


def forbidden_path(path: str) -> bool:
    parts = Path(path).parts
    name = Path(path).name.lower()
    return bool(LOCAL_MATERIAL.search(path)) or any(
        part in {".scratch", ".mooncakes", "__pycache__"} for part in parts
    ) or name in {".env", "id_rsa", "id_ed25519", "credentials.json"} or (
        name.startswith(".env.") and not name.endswith((".example", ".sample"))
    ) or name.endswith((".p12", ".pfx", ".key"))


def scan(data: bytes) -> list[dict[str, object]]:
    findings = []
    for category, pattern in PATTERNS.items():
        for match in pattern.finditer(data):
            # License author contacts and synthetic test addresses are public.
            if category == "contact_email" and match.group().lower().endswith(
                (b"@example.com", b"@example.org", b"@example.net", b"@apache.org")
            ):
                continue
            findings.append({"category": category, "line": data.count(b"\n", 0, match.start()) + 1})
    for match in IPV4.finditer(data):
        try:
            address = ipaddress.ip_address(match.group().decode("ascii"))
        except ValueError:
            continue
        if any(address in network for network in INTERNAL):
            findings.append({"category": "internal_ipv4", "line": data.count(b"\n", 0, match.start()) + 1})
    return findings


def inspect(history: bool) -> dict[str, object]:
    # Check the index and its working copies, so a staged removal is respected.
    paths = [p.decode("utf-8") for p in git("ls-files", "-z").split(b"\0") if p]
    findings = []
    for path in paths:
        if forbidden_path(path):
            findings.append({"path": path, "category": "local_or_credential_file"})
        index_data = git("show", f":{path}")
        for item in scan(index_data):
            findings.append({"path": path, "source": "index", **item})
        work_data = (ROOT / path).read_bytes()
        if work_data != index_data:
            for item in scan(work_data):
                findings.append({"path": path, "source": "working_tree", **item})
    blobs: dict[str, str] = {}
    if history:
        # Enumerate objects once; inspect each historical blob once with cat-file.
        objects = git("rev-list", "--objects", "--all").splitlines()
        object_input = b"\n".join(row.split(b" ", 1)[0] for row in objects) + b"\n"
        metadata = subprocess.run(
            ["git", "-c", f"safe.directory={ROOT.as_posix()}", "cat-file", "--batch-check=%(objectname) %(objecttype)"],
            cwd=ROOT, input=object_input, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        ).stdout.splitlines()
        for row, meta in zip(objects, metadata):
            if meta.endswith(b" blob"):
                oid, _, path = row.partition(b" ")
                blobs[oid.decode("ascii")] = path.decode("utf-8", errors="replace")
        for oid, path in blobs.items():
            for item in scan(git("cat-file", "blob", oid)):
                findings.append({"path": path, "blob": oid, **item})
    # Verify object connectivity without modifying references or deleting objects.
    git("fsck", "--connectivity-only", "--no-reflogs")
    return {
        "head": git("rev-parse", "HEAD").decode().strip(),
        "commit_count": int(git("rev-list", "--count", "HEAD")),
        "tracked_files": len(paths), "historical_blobs": len(blobs),
        "findings": findings,
        "scope": "Tracked working files and all locally reachable historical blobs; heuristic scan, no history rewriting",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--history", action="store_true", help="also scan every reachable historical blob")
    args = parser.parse_args()
    result = inspect(args.history)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["findings"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
