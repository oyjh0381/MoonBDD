# Release Checklist

Run this checklist from a clean `main` checkout with the release toolchain
version recorded in the release notes.

1. Replace `Unreleased` in `CHANGELOG.md`; confirm version, license, repository,
   keywords, and README metadata in `moon.mod`.
2. Run `moon update`, `moon fmt --check`, `moon info`,
   `moon check --target all --deny-warn`, and
   `moon test --target all --deny-warn`.
3. Run `python tools/test_cli.py`, `python tools/benchmark.py`,
   `python tools/count_moonbit_loc.py`, and all three documented examples.
   The LOC command must exit successfully with at least 4,000 non-empty,
   non-line-comment MoonBit source lines.
   Confirm `git diff --exit-code` and `git status` are clean afterward.
4. Run `moon publish --dry-run`; inspect the package file list and generated
   interface. Confirm Apache-2.0 provenance and third-party notices.
5. Push the signed or annotated version tag, let the multi-target GitHub Actions
   workflow pass on the public repository, then publish the exact tagged commit
   to mooncakes.io.
6. Verify the public repository, mooncakes package page, README installation,
   one library example, and one CLI example from a fresh directory. Attach the
   CI URL, package URL, tag, benchmark output, and test summary to the OSC
   acceptance record.

Publishing, pushing, and tagging are intentional external actions and require
the maintainer's credentials and explicit approval.
