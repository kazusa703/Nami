//
//  NamiUITests.swift
//  NamiUITests
//
//  Created by 今井一颯 on 2026/02/09.
//

import XCTest

final class NamiUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {}

    /// Dismiss the ATT dialog if it appears
    private func dismissATTDialog() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for buttonLabel in ["許可", "Allow", "アプリにトラッキングしないように要求", "Ask App Not to Track"] {
            let btn = springboard.buttons[buttonLabel]
            if btn.waitForExistence(timeout: 3) {
                btn.tap()
                sleep(1)
                return
            }
        }
    }

    private func takeScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Stats Range Picker Tests

    @MainActor
    func testStatsRangePickerFullFlow() {
        app.launch()
        dismissATTDialog()

        // Navigate to Stats tab
        let statsTab = app.tabBars.buttons["統計"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10), "Stats tab should exist")
        statsTab.tap()
        sleep(3)

        // Scroll to top to ensure Range Picker is visible
        let scrollView = app.scrollViews.firstMatch
        // Swipe down multiple times to ensure we're at top
        for _ in 0 ..< 5 {
            scrollView.swipeDown()
        }
        sleep(1)

        // Take initial screenshot
        takeScreenshot("01_Stats_Top")

        // Debug: print all visible buttons
        let allButtons = app.buttons.allElementsBoundByIndex
        print("=== VISIBLE BUTTONS ===")
        for btn in allButtons {
            print("Button: label='\(btn.label)', id='\(btn.identifier)', frame=\(btn.frame)")
        }
        print("=== END BUTTONS ===")

        // Debug: print all visible static texts
        let allTexts = app.staticTexts.allElementsBoundByIndex
        print("=== VISIBLE TEXTS ===")
        for text in allTexts.prefix(30) {
            print("Text: '\(text.label)', frame=\(text.frame)")
        }
        print("=== END TEXTS ===")

        // Look for Range Picker by text content
        let oneWeekText = app.staticTexts["1W"]
        let allPeriodText = app.staticTexts["全期間"]

        if oneWeekText.exists {
            print("Found 1W text at: \(oneWeekText.frame)")
        }
        if allPeriodText.exists {
            print("Found 全期間 text at: \(allPeriodText.frame)")
        }

        // Try finding buttons by text label
        let weekBtn = app.buttons.matching(NSPredicate(format: "label == '1W'")).firstMatch
        let allBtn = app.buttons.matching(NSPredicate(format: "label == '全期間'")).firstMatch

        // Take screenshot of whatever we see
        takeScreenshot("02_Stats_AfterScrollUp")

        // If buttons exist, test the range picker
        if weekBtn.exists || oneWeekText.exists {
            let tapTarget = weekBtn.exists ? weekBtn : oneWeekText
            tapTarget.tap()
            sleep(1)
            takeScreenshot("03_Stats_1W")

            // Switch to 1M
            let monthTarget = app.buttons.matching(NSPredicate(format: "label == '1M'")).firstMatch
            if monthTarget.exists {
                monthTarget.tap()
                sleep(1)
                takeScreenshot("04_Stats_1M")
            } else if app.staticTexts["1M"].exists {
                app.staticTexts["1M"].tap()
                sleep(1)
                takeScreenshot("04_Stats_1M")
            }

            // Switch to 3M
            let threeM = app.staticTexts["3M"].exists ? app.staticTexts["3M"] : app.buttons.matching(NSPredicate(format: "label == '3M'")).firstMatch
            if threeM.exists {
                threeM.tap()
                sleep(1)
                takeScreenshot("05_Stats_3M")
            }

            // Switch to 1Y
            let oneY = app.staticTexts["1Y"].exists ? app.staticTexts["1Y"] : app.buttons.matching(NSPredicate(format: "label == '1Y'")).firstMatch
            if oneY.exists {
                oneY.tap()
                sleep(1)
                takeScreenshot("06_Stats_1Y")
            }

            // Back to 全期間
            let allTarget = allBtn.exists ? allBtn : allPeriodText
            if allTarget.exists {
                allTarget.tap()
                sleep(1)
                takeScreenshot("07_Stats_AllPeriod")
            }
        } else {
            // Range picker not found - screenshot current state for diagnosis
            XCTFail("Range Picker not found in Stats view")
        }

        // Scroll down to summaryCards
        scrollView.swipeUp()
        sleep(1)
        takeScreenshot("08_Stats_Scrolled1")

        scrollView.swipeUp()
        sleep(1)
        takeScreenshot("09_Stats_Scrolled2")

        scrollView.swipeUp()
        sleep(1)
        takeScreenshot("10_Stats_Scrolled3")

        scrollView.swipeUp()
        sleep(1)
        takeScreenshot("11_Stats_Scrolled4")

        // Keep scrolling to PRO section and activity
        for i in 0 ..< 6 {
            scrollView.swipeUp()
            sleep(1)
            takeScreenshot("12_Stats_Deep\(i)")
        }
    }
}
