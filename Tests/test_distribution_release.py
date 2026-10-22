#!/usr/bin/env python3
"""Source-only public distribution does not silently ship a binary."""
import pathlib, subprocess, unittest, plistlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ReleaseContracts(unittest.TestCase):
    def test_distribution_plist_matches_core_identity(self):
        info=plistlib.loads((ROOT/'scripts/release/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleIdentifier'],'dev.aichecker.localapp')
        self.assertEqual(info['CFBundleExecutable'],'AIChecker')
        self.assertEqual(info['CFBundleShortVersionString'],'1.10.1')
        self.assertEqual(info['CFBundleIconFile'],'AppIcon.icns')
        self.assertTrue(info['LSUIElement'])
        self.assertIn('Kenshin Fuwa', info['NSHumanReadableCopyright'])
    def test_no_release_without_notorization(self):
        s=(ROOT/'scripts/build-notarized-dmg.sh').read_text()
        for key in ['Developer ID Application:', '--options runtime', '--timestamp',
                    'notarytool submit', "status != 'Accepted'",'stapler staple','stapler validate','hdiutil verify', 'build-universal-binary.sh', 'lipo -verify_arch arm64 x86_64']:
            self.assertIn(key,s)
        self.assertLess(s.index("status != 'Accepted'"),s.index('mkdir -p "$ROOT/dist"'))
        self.assertNotIn('gh release create',s)
        self.assertNotIn('sudo ',s)
        self.assertNotIn('killall ',s)
    def test_scripts_shell_syntax(self):
        for name in ['build-notarized-dmg.sh','propose-github-beta.sh','build-universal-binary.sh','check-universal-build.sh']:
            subprocess.run(['bash','-n',str(ROOT/'scripts'/name)],check=True)
    def test_universal_ci_gate_is_separate_and_never_publishes_unsigned_binary(self):
        wf=(ROOT/'.github/workflows/mac-validation.yml').read_text()
        build=(ROOT/'scripts/build-universal-binary.sh').read_text()
        wrapper=(ROOT/'scripts/check-universal-build.sh').read_text()
        for marker in ['universal-macos:', 'macos-latest', 'scripts/check-universal-build.sh']:
            self.assertIn(marker, wf)
        for marker in ['--arch "$ARCH"', 'for ARCH in arm64 x86_64', 'lipo -create',
                       'lipo -verify_arch arm64 x86_64', 'NOT signed, NOT notarized']:
            self.assertIn(marker, build)
        self.assertIn('trap cleanup EXIT', build)
        self.assertIn('trap cleanup EXIT', wrapper)
        self.assertIn('bash scripts/build-universal-binary.sh', wrapper)
        self.assertNotIn('gh release', build)
        self.assertNotIn('gh release', wrapper)
        self.assertNotIn('codesign --sign', build)
        self.assertNotIn('/Applications/AI Checker.app', build)
    def test_public_bundle_does_not_contain_provider_images(self):
        self.assertFalse(list((ROOT/'Sources/AIChecker/Assets').glob('*.png')))
if __name__=='__main__': unittest.main(verbosity=2)
