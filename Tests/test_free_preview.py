#!/usr/bin/env python3
"""Contract tests preventing an unnotarized beta from being mistaken for a public release."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FreePreviewContracts(unittest.TestCase):
    def test_manual_workflow_only(self):
        txt = (ROOT / '.github/workflows/unnotarized-preview.yml').read_text()
        self.assertIn('workflow_dispatch:', txt)
        self.assertNotIn('  pull_request:', txt)
        self.assertNotIn('  push:', txt)
        self.assertIn("github.ref == 'refs/heads/main'", txt)
        self.assertIn("inputs.acknowledge_unnotarized == 'UNNOTARIZED_TEST_ONLY'", txt)
        self.assertIn('permissions:\n  contents: read', txt)
        self.assertIn('retention-days: 7', txt)
        self.assertIn('actions/upload-artifact@v4', txt)
        self.assertIn('if-no-files-found: error', txt)
        self.assertIn('UNNOTARIZED-PREVIEW-NOT-APPLE-VERIFIED', txt)

    def test_preview_not_misrepresented_as_release(self):
        script = (ROOT / 'scripts/build-free-preview-dmg.sh').read_text()
        workflow = (ROOT / '.github/workflows/unnotarized-preview.yml').read_text()
        self.assertIn('--acknowledge-unnotarized-preview', script)
        self.assertIn('codesign --force --sign -', script)
        self.assertIn('Signature=adhoc', script)
        self.assertIn('codesign --verify --strict', script)
        self.assertIn('audit-release-dmg.sh --unsigned-preflight', script)
        self.assertIn('verify-release-checksum.py', script)
        self.assertIn('No installed app was changed', script)
        for txt in (script, workflow):
            for forbidden in ('notarytool submit', 'stapler staple', 'gh release create',
                              'spctl --master-disable', 'xattr -dr', 'sudo ',
                              'killall ', 'install-local.sh'):
                self.assertNotIn(forbidden, txt)
        self.assertNotIn('actions/upload-artifact', (ROOT / '.github/workflows/mac-validation.yml').read_text())
        self.assertIn('notarytool submit', (ROOT / 'scripts/build-notarized-dmg.sh').read_text())

    def test_no_existing_install_replacement(self):
        script = (ROOT / 'scripts/build-free-preview-dmg.sh').read_text()
        self.assertNotIn('"/Applications/AI Checker.app"', script)
        self.assertNotIn('"$HOME/Applications/AI Checker.app"', script)
        self.assertIn('refusing overwrite', script)
        self.assertIn('trap cleanup EXIT', script)
        self.assertIn('READ-ME-UNNOTARIZED.txt', script)
        self.assertIn('no GitHub Release', script)

    def test_docs_explicitly_explain_risks(self):
        guide = (ROOT / 'docs/UNNOTARIZED_TEST_PREVIEW.md').read_text()
        for marker in ('notarized', 'Developer ID', 'Gatekeeper', 'overwrite', 'UNNOTARIZED_TEST_ONLY'):
            self.assertIn(marker, guide)

    def test_shell_parse(self):
        subprocess.run(['bash', '-n', str(ROOT / 'scripts/build-free-preview-dmg.sh')], check=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
