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
                    'notarytool submit', "status != 'Accepted'",'stapler staple','stapler validate','hdiutil verify']:
            self.assertIn(key,s)
        self.assertLess(s.index("status != 'Accepted'"),s.index('mkdir -p "$ROOT/dist"'))
        self.assertNotIn('gh release create',s)
        self.assertNotIn('sudo ',s)
        self.assertNotIn('killall ',s)
    def test_scripts_shell_syntax(self):
        for name in ['build-notarized-dmg.sh','propose-github-beta.sh']:
            subprocess.run(['bash','-n',str(ROOT/'scripts'/name)],check=True)
    def test_public_bundle_does_not_contain_provider_images(self):
        self.assertFalse(list((ROOT/'Sources/AIChecker/Assets').glob('*.png')))
if __name__=='__main__': unittest.main(verbosity=2)
