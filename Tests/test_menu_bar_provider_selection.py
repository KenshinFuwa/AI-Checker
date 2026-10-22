"""Source contracts for per-provider, opt-in menu-bar reporting."""
import pathlib
import unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/AIChecker/main.swift').read_text()
ART = (ROOT / 'Sources/AIChecker/StatusArtwork.swift').read_text()

class ProviderMenuBarSelectionTests(unittest.TestCase):
    def test_shared_stay_open_provider_selector(self):
        self.assertIn('addMenuBarProviderSelectionMenu(to: menu)', MAIN)
        self.assertIn('"メニューバーに表示するAI"', MAIN)
        self.assertIn('selectedAPIMenuBarIDs.contains(kind.rawValue)', MAIN)
        self.assertIn('settings.setVisible(id, !settings.visibleProviderIDs.contains(id))', MAIN)
        self.assertIn('self?.toggleCopilotBar()', MAIN)
        self.assertNotIn('addUnsupportedProviderSubmenu', MAIN)

    def test_selection_is_opt_in_and_persisted_without_credentials(self):
        self.assertIn('AIChecker.v110.apiMenuBarSelection', MAIN)
        self.assertIn('stringArray(forKey: apiMenuBarSelectionKey) ?? []', MAIN)
        self.assertIn('selectedAPIMenuBarIDs.sorted()', MAIN)
        self.assertIn('externalClients[kind]?.configured == true', MAIN)
        self.assertNotIn('UserDefaults.standard.set(report.value', MAIN)
        self.assertIn('loadAPIMenuBarSelection()', MAIN)

    def test_missing_api_reports_are_unknown_not_quota(self):
        self.assertIn('return prefix + " —"', MAIN)
        self.assertIn('report.periodStart == thisMonth', MAIN)
        self.assertIn('monthlyAPIReports: currentAPIMenuBarLabels', MAIN)
        self.assertIn('monthlyAPIReports: [String] = []', ART)
        self.assertIn('NEVER 5h/Week percentages', ART)
        self.assertNotIn('remainingPercent', MAIN.split('private var currentAPIMenuBarLabels:',1)[1].split('private func addMenuBarProviderSelectionMenu',1)[0])

    def test_recoverable_empty_selection_and_original_icons(self):
        self.assertIn('?? StatusArtwork.renderLauncherIcon()', MAIN)
        self.assertIn('ProviderIconArtwork.draw', ART)
        self.assertIn('let reportLabels =', ART)
        self.assertNotIn('if preferences.visibleProviderIDs.isEmpty { preferences.setVisible', MAIN)

if __name__ == '__main__': unittest.main(verbosity=2)
