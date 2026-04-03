//
//  InboxZeroMailUITestsLaunchTests.swift
//  InboxZeroMailUITests
//
//  Created by Eliezer Steinbock on 28/03/2026.
//

import AppKit
import XCTest

final class InboxZeroMailUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--seed-demo-data",
            "--ui-testing",
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO",
        ]
        app.launchEnvironment["ApplePersistenceIgnoreState"] = "YES"
        app.launchEnvironment["INBOX_ZERO_UI_TESTING"] = "1"
        if #available(macOS 14.0, *) {
            _ = NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            NSApplication.shared.yieldActivation(toApplicationWithBundleIdentifier: "com.getinboxzero.InboxZeroMail")
        }
        app.activate()
        defer {
            if app.state != .notRunning {
                app.terminate()
            }
        }

        XCTAssertTrue(app.buttons["toolbar-compose"].waitForExistence(timeout: 10))
    }
}
