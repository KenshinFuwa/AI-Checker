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
    def test_historical_publishers_are_disabled_and_fail_closed(self):
        import subprocess
        for name in ('publish-github.sh', 'propose-github-beta.sh'):
            path = ROOT / 'scripts' / name
            script = path.read_text()
            self.assertIn('Historical GitHub publication automation is disabled', script)
            self.assertIn('exit 78', script)
            self.assertNotIn('gh auth', script)
            self.assertNotIn('git push', script)
            self.assertNotIn('gh repo create', script)
            result = subprocess.run(['bash', str(path)], cwd=str(ROOT),
                                    text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 78, name)
            self.assertIn('BLOCKED', result.stderr)

    def test_public_source_has_no_git_whitespace_errors(self):
        # Catch release-blocking whitespace before cloning/pushing to GitHub.
        ignored = {'.git', '.build', '.swiftpm', 'dist', '__pycache__'}
        suffixes = {'.md', '.swift', '.py', '.sh', '.yml', '.yaml', '.json', '.txt'}
        for file in ROOT.rglob('*'):
            if not file.is_file() or any(part in ignored for part in file.relative_to(ROOT).parts):
                continue
            if file.suffix not in suffixes:
                continue
            data = file.read_bytes()
            self.assertFalse(data.endswith(b'\n\n'), f'{file}: blank line at EOF')
            for index, line in enumerate(data.splitlines(), start=1):
                self.assertFalse(line.endswith((b' ', b'\t')),
                                 f'{file}:{index}: trailing whitespace')

    def test_codex_easy_connection_preserves_explicit_auth_and_cli_boundary(self):
        app=(ROOT/'Sources/AIChecker/main.swift').read_text()
        bridge=(ROOT/'Sources/AIChecker/CodexAccountClient.swift').read_text()
        start=app.index('    private func beginEasyCodexConnection() {')
        end=app.index('    @objc private func loginCodex()', start)
        flow=app[start:end]
        self.assertIn('addStayOpenRow("ChatGPTでかんたん接続…"', app)
        self.assertIn('DispatchQueue.main.async { [weak self] in self?.beginEasyCodexConnection() }', app)
        self.assertIn('guard CodexAccountClient.executable() != nil else', flow)
        self.assertLess(flow.index('guard CodexAccountClient.executable() != nil else'),
                        flow.index('accountConfig.addCodex('))
        self.assertIn('accountConfig.accounts.first(where:', flow)
        self.assertIn('accountConfig.addCodex(label: "個人Codex")', flow)
        self.assertIn('connectSelectedAccount()', flow)
        self.assertIn('codexClient?.login()', flow)
        self.assertIn('https://github.com/openai/codex', flow)
        self.assertIn('chooseCodexExecutable()', flow)
        for forbidden in ('Process()', 'sudo ', 'curl -', 'npm install', 'brew install',
                          'osascript', 'xattr ', 'Keychain', 'rm -rf'):
            self.assertNotIn(forbidden, flow)
        self.assertIn('child.arguments = ["app-server", "--listen", "stdio://"]', bridge)
        self.assertIn('environment["CODEX_HOME"] = home.path', bridge)

    def test_docs_do_not_claim_pre_merge_or_old_version(self):
        readme=(ROOT/'README.md').read_text()
        self.assertNotIn('published `main` branch is currently v1.9.2', readme)
        self.assertNotIn('macOS CI has not been confirmed green', readme)
        self.assertIn('No Developer ID-signed/notarized', readme)
        self.assertIn('checksum', (ROOT/'docs/DISTRIBUTION.md').read_text())
        self.assertIn('source-only prerelease', (ROOT/'RELEASE_NOTES.md').read_text())
        self.assertNotIn('still not created', (ROOT/'docs/PUBLISH_PR.md').read_text())
        self.assertFalse((ROOT/'docs/README.ja.md').exists())
        self.assertFalse((ROOT/'docs/FREE_PREVIEW.ja.md').exists())
        for language in ('en','ja'):
            self.assertTrue((ROOT/f'Localization/{language}.lproj/Localizable.strings').is_file())

    def test_docs_and_ci(self):
        for f in ('README.md','SECURITY.md','LICENSE','PUBLICATION_CHECKLIST.md','docs/UNNOTARIZED_TEST_PREVIEW.md','docs/INSTALL.md','.github/workflows/mac-validation.yml'):
            self.assertTrue((ROOT/f).is_file(),f)
        self.assertIn('macos-latest',(ROOT/'.github/workflows/mac-validation.yml').read_text())
if __name__=='__main__':unittest.main(verbosity=2)
