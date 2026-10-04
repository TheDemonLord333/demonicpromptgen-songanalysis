//
//  demonincpromptgen_songanalysisUITests.swift
//  demonincpromptgen-songanalysisUITests
//

import XCTest

final class demonincpromptgen_songanalysisUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Hauptablauf ohne Anmeldung: Link eingeben, Prompt generieren, kopieren.
    @MainActor
    func testGenerateAndCopyPromptWithoutLogin() throws {
        let app = XCUIApplication()
        app.launch()

        let generate = app.buttons["generatePromptButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        XCTAssertFalse(generate.isEnabled, "Ohne gültigen Link muss die Generierung deaktiviert sein.")

        let field = app.textFields["songURLField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=test")

        XCTAssertTrue(generate.isEnabled)
        generate.tap()

        let prompt = app.staticTexts["promptText"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertTrue(prompt.label.contains("Analysiere mir dieses Lied:"))
        XCTAssertTrue(prompt.label.contains("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"))
        XCTAssertFalse(prompt.label.contains("si=test"))

        let copy = app.buttons["copyPromptButton"]
        XCTAssertTrue(copy.isEnabled)
        copy.tap()
    }

    @MainActor
    func testInvalidLinkShowsValidation() throws {
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields["songURLField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://example.com/song")

        XCTAssertTrue(app.staticTexts["validationMessage"].waitForExistence(timeout: 3)
                      || app.otherElements["validationMessage"].exists)
        XCTAssertFalse(app.buttons["generatePromptButton"].isEnabled)
    }

    @MainActor
    func testSettingsSheetOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["settingsButton"].tap()
        let done = app.buttons["settingsDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["generatePromptButton"].waitForExistence(timeout: 5))
    }
}
