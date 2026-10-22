#!/usr/bin/env python3
import pathlib, unittest, struct
ROOT = pathlib.Path(__file__).resolve().parents[1]
INSTALL = (ROOT / 'scripts/install-local.sh').read_text()
APP = (ROOT / 'Sources/AIChecker/main.swift').read_text()
DIAG = (ROOT / 'scripts/diagnose-app-identity.sh').read_text()

class AppIdentityContracts(unittest.TestCase):
    def test_signed_icon_resource_explicit(self):
        self.assertIn('<key>CFBundleIconFile</key><string>AppIcon.icns</string>', INSTALL)
        self.assertIn('Contents/Resources/AppIcon.icns', INSTALL)
        self.assertIn("printf 'APPL????'", INSTALL)
        self.assertIn('codesign --verify --strict', INSTALL)
        self.assertIn('sips -g pixelWidth -g pixelHeight', INSTALL)
    def test_icon_is_loaded_at_launch_without_touching_finder_cache(self):
        self.assertIn('configureApplicationIcon()', APP)
        self.assertIn('NSApp.applicationIconImage = icon', APP)
        self.assertIn('Bundle.main.url(forResource: "AppIcon", withExtension: "icns")', APP)
    def test_identity_not_migrated(self):
        self.assertIn('dev.aichecker.localapp',INSTALL)
        self.assertIn('LSUIElement</key><true/>',INSTALL)
        self.assertNotIn('mdutil -E',INSTALL)
        self.assertNotIn('tccutil reset',INSTALL)
    def test_spotlight_and_appkit_are_separately_checked(self):
        for tag in ['SPOTLIGHT_METADATA_MATCH:', 'LAUNCH_SERVICES', 'MDLS_CONTENT_TYPE', 'Spotlight indexing comparison']:
            self.assertTrue(tag in DIAG or tag in (ROOT/'scripts/inspect-app-identity.swift').read_text(), tag)
        self.assertNotIn('mdutil -E', DIAG)
        self.assertNotIn('killall', DIAG)
    def test_icns_has_macos_icon_chunks(self):
        icon=(ROOT/'Design/AppIcon.icns').read_bytes()
        self.assertEqual(icon[:4],b'icns')
        self.assertEqual(struct.unpack('>I',icon[4:8])[0],len(icon))
        self.assertGreater(len(icon),10000)
if __name__=='__main__': unittest.main(verbosity=2)
