#!/usr/bin/env python3
import hashlib
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/verify-release-checksum.py'


class ChecksumContracts(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.base = pathlib.Path(self._td.name)
        self.dmg = self.base / 'AI-Checker-v1.10.1-notarized.dmg'
        self.dmg.write_bytes(b'dummy bytes for isolated checksum unit test')
        self.sha = self.base / (self.dmg.name + '.sha256')
        self.hash = hashlib.sha256(self.dmg.read_bytes()).hexdigest()
        self.sha.write_text(self.hash + '  ' + self.dmg.name + '\n')

    def run_check(self, dmg=None, sha=None):
        return subprocess.run([sys.executable, str(SCRIPT), str(dmg or self.dmg), str(sha or self.sha)],
                              text=True, capture_output=True)

    def test_valid_digest(self):
        r = self.run_check()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('integrity only', r.stdout)
        self.assertIn('notarization NOT verified', r.stdout)

    def test_tampered_image_rejected(self):
        self.dmg.write_bytes(self.dmg.read_bytes() + b'tamper')
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_wrong_filename_rejected(self):
        self.sha.write_text(self.hash + '  other.dmg\n')
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_malformed_and_extra_line_rejected(self):
        for content in ('bad', self.hash + ' *' + self.dmg.name + '\n',
                        self.hash + '  ' + self.dmg.name + '\nsecond line\n'):
            with self.subTest(content=content):
                self.sha.write_text(content)
                self.assertNotEqual(self.run_check().returncode, 0)

    def test_symlink_checksum_rejected(self):
        original = self.base / 'actual.sha256'
        self.sha.rename(original)
        self.sha.symlink_to(original)
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_symlink_dmg_rejected(self):
        original = self.base / 'original.dmg'
        self.dmg.rename(original)
        self.dmg.symlink_to(original)
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_nonabsolute_paths_rejected(self):
        result = subprocess.run([sys.executable, str(SCRIPT), 'relative.dmg', 'relative.sha256'],
                                capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_absent_inputs_rejected(self):
        self.sha.unlink()
        self.assertNotEqual(self.run_check().returncode, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
