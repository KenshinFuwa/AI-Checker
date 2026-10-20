#!/usr/bin/env python3
"""A hermetic installer simulation. It never runs codesign or touches the user's HOME."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def write_sh(path, body):
    path.write_text('#!/bin/bash\nset -e\n' + body + '\n')
    path.chmod(0o755)


class OfflineInstallFlowTests(unittest.TestCase):
    def make_env(self, home, mismatch=False, build_failure=False):
        mockbin = home / 'fake-bin'
        mockbin.mkdir()
        appbin = home / 'build' / 'AIChecker'
        appbin.parent.mkdir()
        appbin.write_text('#!/bin/sh\nexit 0\n')
        appbin.chmod(0o755)
        cfg = home / '.config' / 'menupilot'
        cfg.mkdir(parents=True)
        (cfg / 'signing-identity.txt').write_text('ABCD42\n')
        scripts = {
            'uname': "echo Darwin",
            'security': "echo '  1) ABCD42 LocalDevelopment'",
            'swift': f'''if [[ "$*" == *'--show-bin-path'* ]]; then echo '{appbin.parent}' ; exit 0; fi
                    {'exit 41' if build_failure else 'exit 0'}''',
            'plutil': 'echo OK',
            'codesign': '''if [[ "$1" == '--display' ]]; then
                    if [[ "${*: -1}" == *'.AI-Checker-stage.'* ]]; then
                        echo 'designated => signed-profile' >&2
                    else
                        echo 'designated => ''' + ("wrong-profile" if mismatch else "signed-profile") + '''' >&2
                    fi
                    fi
                    exit 0''',
            'pgrep': 'exit 1',
            'open': "echo \"$*\" >> \"$INSTALL_TEST_OPEN_LOG\"",
        }
        for name, body in scripts.items():
            write_sh(mockbin / name, body)
        env = dict(os.environ)
        env['HOME'] = str(home)
        env['PATH'] = f'{mockbin}:{os.environ.get("PATH", "")}'
        env['INSTALL_TEST_OPEN_LOG'] = str(home / 'opened.txt')
        return env

    def run_install(self, home, env, old_exists=True):
        dest = home / 'Applications' / 'AI Checker.app'
        if old_exists:
            (dest / 'Contents' / 'MacOS').mkdir(parents=True)
            (dest / 'Contents' / 'MacOS' / 'AIChecker').write_text('OLD-BINARY')
        result = subprocess.run(['bash', str(ROOT / 'scripts' / 'install-local.sh')],
                                cwd=str(ROOT), env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=25)
        return result, dest

    def test_successful_update_preserves_signed_backup_and_auto_launches(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            env = self.make_env(home)
            result, dest = self.run_install(home, env)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((dest / 'Contents' / 'MacOS' / 'AIChecker').is_file())
            backup = home / 'Applications' / 'AI Checker.previous.app'
            self.assertEqual((backup / 'Contents' / 'MacOS' / 'AIChecker').read_text(), 'OLD-BINARY')
            self.assertIn('AI Checker.app', (home / 'opened.txt').read_text())
            self.assertIn('1.9.2', (dest / 'Contents' / 'Info.plist').read_text())

    def test_build_failure_never_stops_or_overwrites_existing_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            env = self.make_env(home, build_failure=True)
            result, dest = self.run_install(home, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((dest / 'Contents' / 'MacOS' / 'AIChecker').read_text(), 'OLD-BINARY')
            self.assertFalse((home / 'opened.txt').exists())

    def test_signing_requirement_mismatch_preserves_existing_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            env = self.make_env(home, mismatch=True)
            result, dest = self.run_install(home, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('different signing identity', result.stderr)
            self.assertEqual((dest / 'Contents' / 'MacOS' / 'AIChecker').read_text(), 'OLD-BINARY')
            self.assertFalse((home / 'opened.txt').exists())


if __name__ == '__main__':
    unittest.main()
