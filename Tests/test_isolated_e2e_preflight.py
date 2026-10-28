#!/usr/bin/env python3
"""Pure-function policy tests: no process inspection or app launch in test code."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "scripts/preflight-isolated-e2e.py"
spec = importlib.util.spec_from_file_location("aic_e2e_preflight", SRC)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class PreflightPolicy(unittest.TestCase):
    def assess(self, **changes):
        args = dict(os_name="Darwin", uid=501, euid=501, acknowledged=True,
                    home_matches=True, footprints=[], process_result=1)
        args.update(changes)
        return gate.assess(**args)

    def test_clean_user_is_only_preflight_ready(self):
        self.assertEqual(self.assess(), [])
        self.assertIn("NOT E2E PASS", SRC.read_text())

    def test_mac_os_and_explicit_ack_required(self):
        self.assertTrue(self.assess(os_name="Linux"))
        self.assertTrue(self.assess(acknowledged=False))

    def test_root_and_home_override_blocked(self):
        self.assertTrue(self.assess(uid=0, euid=0))
        self.assertTrue(self.assess(euid=0))
        self.assertTrue(self.assess(home_matches=False))

    def test_account_state_and_process_fail_closed(self):
        for name in (".codex", ".claude", "Library/Application Support/AI Checker"):
            self.assertTrue(self.assess(footprints=[name]))
        for status in (0, 2, -1):
            self.assertTrue(self.assess(process_result=status))

    def test_no_credentials_or_install_operations(self):
        source = SRC.read_text()
        for forbidden in ("security find-generic-password", "defaults write",
                          "open -a ", "install-local.sh", "connectSelectedAccount()",
                          "gh release create", "app.run()"):
            self.assertNotIn(forbidden, source)
        self.assertIn("pwd.getpwuid(uid)", source)
        self.assertIn("stdout=subprocess.DEVNULL", source)


if __name__ == "__main__":
    unittest.main()
