#!/usr/bin/env python3
import pathlib,re,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class PublicSourceContracts(unittest.TestCase):
    def test_no_third_party_png_assets(self):
        self.assertEqual(list((ROOT/'Sources').rglob('*.png')), [])
        self.assertIn('ProviderIconArtwork.draw', (ROOT/'Sources/AIChecker/StatusArtwork.swift').read_text())
    def test_package_does_not_exclude_nonexistent_images(self):
        self.assertNotIn('exclude: ["Assets"]',(ROOT/'Package.swift').read_text())
    def test_no_embedded_auth_or_personal_paths(self):
        pats=[re.compile(x,re.I) for x in [r'/Users/[A-Za-z0-9._-]+/',r'gh[pousr]_[A-Za-z0-9]{20,}',r'sk-[A-Za-z0-9]{20,}',r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----']]
        for root in ('Sources','scripts','.github'):
            for path in (ROOT/root).rglob('*'):
                if not path.is_file():continue
                content=path.read_text(errors='replace')
                for p in pats:
                    self.assertIsNone(p.search(content),f'{path}: {p.pattern}')
    def test_license_copyright_holder(self):
        notice=(ROOT/'LICENSE').read_text()
        self.assertIn('Copyright (c) 2026 Kenshin Fuwa',notice)
        self.assertNotIn('MenuPilot contributors',notice)
        for rel in ('README.md','SECURITY.md','PUBLICATION_AUDIT.md','PUBLICATION_CHECKLIST.md'):
            self.assertNotIn('MenuPilot contributors',(ROOT/rel).read_text(),rel)
    def test_public_claude_avoids_undocumented_web_quota_calls(self):
        session=(ROOT/'Sources/AIChecker/ClaudeWebSession.swift').read_text()
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        self.assertNotIn('callAsyncJavaScript',session)
        self.assertNotIn("fetch('/api/organizations'",session)
        self.assertNotIn('scheduleInitialRetries',session)
        self.assertIn('ClaudeStatusLineSource(profileID: profileID)',main)
        self.assertNotIn('Claude専用ブラウザでログイン…',main)
        self.assertIn('return false',main.split('private func claudeWebEnabled(',1)[1].split('private func configureClaudeWebSession()',1)[0])
    def test_publisher_requires_native_gate_and_public_confirmation(self):
        script=(ROOT/'scripts/publish-github.sh').read_text()
        self.assertIn('if [[ "$(uname -s)" != Darwin ]]',script)
        self.assertIn('gh auth status',script)
        self.assertIn('gh repo create "$REPOSITORY" --public',script)
        self.assertIn('Type PUBLISH',script)
        self.assertIn('python3 scripts/verify-source-manifest.py',script)
        self.assertIn('git diff --cached --check',script)
        self.assertIn('users.noreply.github.com',script)

    def test_docs_and_ci(self):
        for f in ('README.md','SECURITY.md','LICENSE','PUBLICATION_CHECKLIST.md','docs/README.ja.md','docs/INSTALL.md','.github/workflows/mac-validation.yml'):
            self.assertTrue((ROOT/f).is_file(),f)
        self.assertIn('macos-latest',(ROOT/'.github/workflows/mac-validation.yml').read_text())
if __name__=='__main__':unittest.main(verbosity=2)
