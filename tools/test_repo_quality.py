"""Regression tests for redacted credential detection and local-file exclusions."""
import unittest
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch

from repo_quality import forbidden_path, scan
import repo_quality


class PreflightTest(unittest.TestCase):
    def test_sensitive_categories_are_redacted(self):
        fixtures = {
            "private_key": b"-----BEGIN " + b"OPENSSH PRIVATE KEY-----",
            "github_token": b"ghp_" + b"A" * 36,
            "aws_access_key": b"AKIA" + b"A" * 16,
            "credential_assignment": b'client_secret="' + b"s" * 20 + b'"',
            "contact_email": b"person@" + b"company.invalid",
            "internal_ipv4": b"http://" + b"192.168." + b"4.9/service",
        }
        for category, fixture in fixtures.items():
            with self.subTest(category=category):
                result = scan(b"safe line\n" + fixture)
                self.assertIn({"category": category, "line": 2}, result)
                self.assertNotIn(fixture.decode(), str(result))

    def test_public_examples_and_moonbit_aliases(self):
        for text in (b"@moonbdd.Manager::new()", b"@apache.org", b"test@example.com",
                     b"127.0.0.1", b"198.51.100.7", b"192.168.999.1", b"1192.168.4.9"):
            with self.subTest(text=text):
                self.assertEqual(scan(text), [])

    def test_private_address_boundaries(self):
        for suffix, expected in ((b"15.255.255", False), (b"16.0.1", True),
                                 (b"31.255.255", True), (b"32.0.1", False)):
            text = b"172." + suffix
            self.assertEqual(bool(scan(text)), expected)

    def test_paths(self):
        for path in ("MoonBDD项目申报书.md", "docs/ECOSYSTEM_REVIEW.md",
                     ".env.local", "nested/id_rsa", "cache/__pycache__/x.pyc"):
            self.assertTrue(forbidden_path(path), path)
        for path in ("README.md", "docs/API.md", ".env.example", "tools/repo_quality.py"):
            self.assertFalse(forbidden_path(path), path)

    def test_index_and_history_are_scanned_even_when_working_copy_is_clean(self):
        with tempfile.TemporaryDirectory(prefix="moonbdd-preflight-") as directory:
            root = Path(directory)

            def command(*args):
                subprocess.run(["git", "-c", f"safe.directory={root.as_posix()}", *args],
                               cwd=root, check=True, capture_output=True)

            command("init", "--initial-branch=main")
            command("config", "user.name", "Fixture")
            command("config", "user.email", "fixture@example.com")
            file = root / "fixture.txt"
            file.write_text("ghp_" + "A" * 36, encoding="utf-8")
            command("add", "fixture.txt")
            command("-c", "commit.gpgsign=false", "commit", "-m", "credential fixture")
            file.write_text("clean working file\n", encoding="utf-8")
            with patch.object(repo_quality, "ROOT", root):
                staged = repo_quality.inspect(False)
                self.assertEqual(staged["findings"][0]["source"], "index")
                command("add", "fixture.txt")
                self.assertEqual(repo_quality.inspect(False)["findings"], [])
                historical = repo_quality.inspect(True)
                self.assertEqual(historical["historical_blobs"], 1)
                self.assertEqual(historical["findings"][0]["category"], "github_token")
                self.assertIn("blob", historical["findings"][0])
                self.assertNotIn("ghp_" + "A" * 36, str(historical))


if __name__ == "__main__":
    unittest.main()
