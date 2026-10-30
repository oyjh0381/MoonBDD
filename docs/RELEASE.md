# Release Checklist

Run this checklist from a clean `main` checkout with the release toolchain
version recorded in the release notes.

1. Replace `Unreleased` in `CHANGELOG.md`; confirm version, license, repository,
   keywords, and README metadata in `moon.mod`.
2. Run `moon update`, `moon fmt --check`, `moon info`,
   `moon check --target all --deny-warn`,
   `moon build --target all --deny-warn`, and
   `moon test --target all --deny-warn`. The minimum compiler is 0.10.16;
   record the full output of `moon version --all`.
3. Run `python tools/test_cli.py`, `python tools/benchmark.py`,
   `python tools/count_moonbit_loc.py`, and all three documented examples.
   The LOC command must exit successfully with at least 4,000 non-empty,
   non-line-comment MoonBit source lines.
   Confirm `git diff --exit-code` and `git status` are clean afterward.
4. Run `moon package --list` for an offline package-content inspection and
   `python tools/repo_quality.py --history` for redacted credential findings.
   Confirm Apache-2.0 provenance and third-party notices. Never use a publish
   command to test packaging: publishing can change the registry.
5. For a separately authorized public release, push the signed or annotated
   version tag, let the multi-target GitHub Actions workflow pass, then publish
   the exact tagged commit to mooncakes.io. Private submission preparation is
   not a package release and does not require tags or publication.
6. For a public release, verify the public repository, mooncakes package page, README installation,
   one library example, and one CLI example from a fresh directory. Attach the
   CI URL, package URL, tag, benchmark output, and test summary to the OSC
   acceptance record.

For a private repository submission, use the exact pushed commit SHA whose CI
passed. Authorize only the intended repository in the submission platform.
Uploading captures a snapshot: later pushes do not update it automatically.
Choose contiguous Milestone intervals from the real development history and
describe the actual changes. Reuploading resets platform checks and Milestones;
editing a Milestone invalidates its quality check. Repository preflight and CI
are local evidence, not a substitute for platform acceptance.

Publishing, pushing, and tagging are intentional external actions and require
the maintainer's credentials and explicit approval.
