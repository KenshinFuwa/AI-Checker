#!/usr/bin/env python3
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/'Sources/AIChecker/main.swift').read_text()
SAMPLER=(ROOT/'Sources/AIChecker/OnDemandNetworkSpeed.swift').read_text()
HEADER=(ROOT/'Sources/AIChecker/UsageSpeedHeaderView.swift').read_text()
MIGRATE=(ROOT/'scripts/migrate-spotlight-app.sh').read_text()
DIAG=(ROOT/'scripts/diagnose-spotlight.sh').read_text()
INSTALL=(ROOT/'scripts/install-local.sh').read_text()
class NewIntegration(unittest.TestCase):
    def test_menu_scoped_half_second_then_one_second(self):
        self.assertIn('.milliseconds(500)', SAMPLER)
        self.assertIn('repeating: .seconds(1)', SAMPLER)
        self.assertIn('getifaddrs(&head)', SAMPLER)
        self.assertIn('systemUptime', SAMPLER)
        self.assertIn('func start(completion:', SAMPLER)
        self.assertIn('func stop()', SAMPLER)
        self.assertIn('guard timer == nil else { return }', SAMPLER)
        self.assertIn('timer?.cancel()', SAMPLER)
        self.assertIn('self.generation == token', SAMPLER)
        self.assertNotIn('Timer.scheduledTimer', SAMPLER)
        self.assertNotIn('func measure(', SAMPLER)

    def test_first_half_second_and_display_every_two_samples(self):
        self.assertIn('baseline.firstReadingComplete', SAMPLER)
        self.assertIn('TwoSecondNetworkAverage()', SAMPLER)
        self.assertIn('baseline.average.append(input, elapsed: elapsed)', SAMPLER)
        self.assertIn('guard let publish else { return }', SAMPLER)
        core = (ROOT/'Sources/AICheckerCore/TwoSecondNetworkAverage.swift').read_text()
        self.assertIn('guard sampleCount == 2 else { return nil }', core)
        self.assertIn('downBitTotal / totalSeconds', core)

    def test_speed_starts_automatically_and_stops_at_menu_close(self):
        opening = MAIN.split('func menuWillOpen(_ menu: NSMenu)', 1)[1].split('func menuDidClose(_ menu: NSMenu)', 1)[0]
        closing = MAIN.split('func menuDidClose(_ menu: NSMenu)', 1)[1].split('private func addStayOpenRow', 1)[0]
        self.assertIn('startMenuNetworkSpeed()', opening)
        self.assertIn('networkSpeed.start {', opening)
        self.assertIn('speedHeader?.begin()', opening)
        self.assertIn('networkSpeed.stop()', closing)
        self.assertIn('speedHeader?.end()', closing)
        self.assertIn('networkSpeed.stop()', MAIN.split('func applicationWillTerminate(',1)[1].split('private func',1)[0])
        self.assertIn('networkSpeed.stop()', MAIN.split('@objc private func willSleep(',1)[1].split('@objc private func didWake(',1)[0])

    def test_one_interface_no_double_count(self):
        self.assertIn('let physical = readings.filter',SAMPLER)
        self.assertIn('let candidates = physical.isEmpty ? readings : physical',SAMPLER)
        self.assertIn('guard let chosen = candidates.max(',SAMPLER)
        self.assertNotIn('reduce(0',SAMPLER)
        self.assertIn('current.receive &- previous.receive',SAMPLER)
    def test_live_header_is_passive_and_non_dismissive(self):
        self.assertIn('heading.view = speedHeader', MAIN)
        self.assertIn('self.speedHeader?.show(outcome)', MAIN)
        self.assertIn('displayIfNeeded()', HEADER)
        self.assertIn('AI CHECKER  /  USAGE', HEADER)
        self.assertNotIn('override func mouseUp', HEADER)
        self.assertNotIn('onMeasure', HEADER)

    def test_spotlight_diagnostic_is_nondestructive(self):
        self.assertIn('mdls -name kMDItemContentType', DIAG)
        self.assertIn('mdfind ',DIAG)
        self.assertIn('SPOTLIGHT_METADATA_MATCH: NOT_CONFIRMED',DIAG)
        self.assertIn('mdimport -i "$APP"',DIAG)
        self.assertNotIn('mdutil -E',DIAG)
        self.assertNotIn('sudo ',DIAG)
        self.assertIn('mdimport -t -d2', DIAG)
        self.assertIn('SPOTLIGHT_IMPORTER_METADATA:', DIAG)
        self.assertIn('Search Privacy', DIAG)
    def test_system_migration_requires_confirmation_and_signature(self):
        self.assertIn('Type MOVE to continue', MIGRATE)
        self.assertIn('codesign --verify --strict',MIGRATE)
        self.assertIn('sudo ditto "$SOURCE" "$STAGE"',MIGRATE)
        self.assertIn('mv "$BACKUP" "$SOURCE"',MIGRATE)
        self.assertIn('mdimport -i "$DEST"',MIGRATE)
        self.assertIn("SYSTEM_APPLICATIONS_DIR='/Applications'",INSTALL)
        self.assertIn('AI_CHECKER_INSTALL_TESTING',INSTALL)
        self.assertIn('AI_CHECKER_TEST_SYSTEM_APPLICATIONS_DIR',INSTALL)
        self.assertIn('if $SYSTEM_INSTALL; then',INSTALL)
if __name__=='__main__': unittest.main(verbosity=2)
