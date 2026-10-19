import XCTest
@testable import Styxpad

final class UpdatePreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "Styxpad.UpdatePreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testPreservesOptOut() {
        defaults.set(false, forKey: "checkForUpdatesAutomatically")
        UpdateChecker.migratePreferences(in: defaults)
        XCTAssertEqual(defaults.object(forKey: "SUEnableAutomaticChecks") as? Bool, false)
    }

    func testPreservesOptIn() {
        defaults.set(true, forKey: "checkForUpdatesAutomatically")
        UpdateChecker.migratePreferences(in: defaults)
        XCTAssertEqual(defaults.object(forKey: "SUEnableAutomaticChecks") as? Bool, true)
    }

    func testNeverOverwritesASparklePreference() {
        defaults.set(true, forKey: "checkForUpdatesAutomatically")
        defaults.set(false, forKey: "SUEnableAutomaticChecks")
        UpdateChecker.migratePreferences(in: defaults)
        UpdateChecker.migratePreferences(in: defaults)
        XCTAssertFalse(defaults.bool(forKey: "SUEnableAutomaticChecks"))
    }

    func testNewInstallUsesBundleDefaults() {
        UpdateChecker.migratePreferences(in: defaults)
        XCTAssertNil(defaults.object(forKey: "SUEnableAutomaticChecks"))
        XCTAssertNil(defaults.object(forKey: "SUAutomaticallyUpdate"))
    }
}
