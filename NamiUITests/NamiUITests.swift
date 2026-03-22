//
//  NamiUITests.swift
//  NamiUITests
//
//  Created by 今井一颯 on 2026/02/09.
//

import XCTest

final class NamiUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - 全機能テスト（初回ユーザーとして）

    @MainActor
    func testFullUserJourney() throws {
        let app = XCUIApplication()
        // オンボーディングをリセット
        app.launchArguments += ["-hasCompletedOnboarding", "NO"]
        app.launch()
        sleep(2)

        var step = 0

        func snap(_ name: String) {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(String(format: "%02d", step))_\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if let data = screenshot.image.pngData() {
                let url = URL(fileURLWithPath: "/tmp/nami_full_\(String(format: "%02d", step))_\(name).png")
                try? data.write(to: url)
            }
            step += 1
        }

        // =============================================
        // Phase 1: オンボーディング
        // =============================================

        snap("onboarding_welcome")

        // 「次へ」ボタンをタップして進む
        func tapNext() {
            let nextBtn = app.buttons["次へ"]
            if nextBtn.waitForExistence(timeout: 3) && nextBtn.isHittable {
                nextBtn.tap()
                sleep(1)
            }
        }

        tapNext() // Step 0 → Step 1 (テーマ選択)
        snap("onboarding_theme")

        // テーマ「Lavender」を試す
        let lavender = app.staticTexts["Lavender"]
        if lavender.waitForExistence(timeout: 3) {
            lavender.tap()
            sleep(1)
            snap("onboarding_theme_lavender")
        }

        // 「Ocean」に戻す
        let ocean = app.staticTexts["Ocean"]
        if ocean.waitForExistence(timeout: 2) {
            ocean.tap()
            sleep(1)
        }

        tapNext() // Step 1 → Step 2 (スコア範囲)
        snap("onboarding_scorerange")

        tapNext() // Step 2 → Step 3 (通知)
        snap("onboarding_notification")

        tapNext() // Step 3 → Step 4 (完了)
        snap("onboarding_done")

        // 「はじめる」ボタン
        let startBtn = app.buttons["はじめる"]
        if startBtn.waitForExistence(timeout: 3) {
            startBtn.tap()
            sleep(2)
        }
        snap("main_after_onboarding")

        // =============================================
        // Phase 2: 記録画面（メイン）
        // =============================================

        // 空の状態を確認
        snap("main_empty")

        // スコア「7」をタップして記録
        let score7 = app.buttons.matching(NSPredicate(format: "label CONTAINS '7'")).firstMatch
        if score7.waitForExistence(timeout: 5) && score7.isHittable {
            score7.tap()
            sleep(2)
            snap("main_after_record_7")
        }

        // RecordingSheetが出ているはず
        // メモ入力を試す
        let memoField = app.textViews.firstMatch
        if memoField.waitForExistence(timeout: 3) {
            snap("recording_sheet_memo")

            // クイックテンプレートを試す
            let template = app.staticTexts["楽しかった"]
            if template.waitForExistence(timeout: 2) && template.isHittable {
                template.tap()
                sleep(1)
                snap("recording_sheet_memo_template")
            }
        }

        // タグタブに移動
        let tagTab = app.staticTexts["タグ"]
        if tagTab.waitForExistence(timeout: 2) && tagTab.isHittable {
            tagTab.tap()
            sleep(1)
            snap("recording_sheet_tags")

            // タグを1つ選択
            let happyTag = app.staticTexts["嬉しい"]
            if happyTag.waitForExistence(timeout: 2) && happyTag.isHittable {
                happyTag.tap()
                sleep(1)
                snap("recording_sheet_tag_selected")
            }
        }

        // 写真タブを確認
        let photoTab = app.staticTexts["写真"]
        if photoTab.waitForExistence(timeout: 2) && photoTab.isHittable {
            photoTab.tap()
            sleep(1)
            snap("recording_sheet_photo")
        }

        // ボイスタブを確認
        let voiceTab = app.staticTexts["ボイス"]
        if voiceTab.waitForExistence(timeout: 2) && voiceTab.isHittable {
            voiceTab.tap()
            sleep(1)
            snap("recording_sheet_voice")
        }

        // 保存
        let saveBtn = app.buttons["保存"]
        if saveBtn.waitForExistence(timeout: 3) && saveBtn.isHittable {
            saveBtn.tap()
            sleep(2)
            snap("main_after_save")
        }

        // もう1件記録（スコア3）
        let score3 = app.buttons.matching(NSPredicate(format: "label CONTAINS '3'")).firstMatch
        if score3.waitForExistence(timeout: 3) && score3.isHittable {
            score3.tap()
            sleep(2)

            // 今回は詳細なしで閉じる
            let skipBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS '閉じる'")).firstMatch
            if skipBtn.waitForExistence(timeout: 3) && skipBtn.isHittable {
                skipBtn.tap()
                sleep(1)
            }
            snap("main_two_records")
        }

        // もう1件記録（スコア5）
        let score5 = app.buttons.matching(NSPredicate(format: "label CONTAINS '5'")).firstMatch
        if score5.waitForExistence(timeout: 3) && score5.isHittable {
            score5.tap()
            sleep(2)
            let skipBtn2 = app.buttons.matching(NSPredicate(format: "label CONTAINS '閉じる'")).firstMatch
            if skipBtn2.waitForExistence(timeout: 3) && skipBtn2.isHittable {
                skipBtn2.tap()
                sleep(1)
            }
        }
        snap("main_three_records")

        // =============================================
        // Phase 3: グラフタブ
        // =============================================

        // タブに移動（staticTextsかbuttonsのどちらかで見つかる）
        func tapTab(_ label: String) {
            if let tab = findElement(app: app, label: label) {
                tab.tap()
                sleep(2)
            }
        }

        tapTab("グラフ")
        snap("graph_line_default")

        // 棒グラフモードに切り替え
        let barBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS '棒'")).firstMatch
        if barBtn.waitForExistence(timeout: 3) && barBtn.isHittable {
            barBtn.tap()
            sleep(1)
            snap("graph_bar")
        }

        // ピクセルモードに切り替え
        let pixelBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ピクセル'")).firstMatch
        if pixelBtn.waitForExistence(timeout: 3) && pixelBtn.isHittable {
            pixelBtn.tap()
            sleep(1)
            snap("graph_pixel")
        }

        // 折れ線に戻す
        let lineBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS '折れ線'")).firstMatch
        if lineBtn.waitForExistence(timeout: 3) && lineBtn.isHittable {
            lineBtn.tap()
            sleep(1)
            snap("graph_line_back")
        }

        // 期間メニューを探す
        // チャート領域をタップ（日別詳細を見る）
        let chartArea = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        chartArea.tap()
        sleep(2)
        snap("graph_day_detail")

        // 戻るボタンがあれば押す
        let backBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS '戻る'")).firstMatch
        if backBtn.waitForExistence(timeout: 3) && backBtn.isHittable {
            backBtn.tap()
            sleep(1)
        }

        // 全画面ボタン
        var foundFullscreen = false
        let buttonsQuery = app.buttons
        for i in 0..<min(buttonsQuery.count, 30) {
            let btn = buttonsQuery.element(boundBy: i)
            if btn.exists && btn.isHittable {
                let label = btn.label
                if label.contains("arrow") || label.contains("expand") || label.contains("fullscreen") || label.contains("全画面") {
                    btn.tap()
                    foundFullscreen = true
                    break
                }
            }
        }
        if !foundFullscreen {
            let coord = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.14))
            coord.tap()
        }
        sleep(2)
        snap("graph_fullscreen")

        // 横画面テスト
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        snap("graph_fullscreen_landscape")

        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        snap("graph_fullscreen_portrait_back")

        // 全画面を閉じる
        let closeBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'xmark' OR label CONTAINS '閉じる' OR label CONTAINS 'close'")).firstMatch
        if closeBtn.waitForExistence(timeout: 3) && closeBtn.isHittable {
            closeBtn.tap()
            sleep(1)
        } else {
            // 座標で閉じる
            let closeCoord = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.08))
            closeCoord.tap()
            sleep(1)
        }
        snap("graph_after_fullscreen_close")

        // =============================================
        // Phase 4: 統計タブ
        // =============================================

        tapTab("統計")
        snap("stats_overview")

        // スクロールして全体を見る
        app.swipeUp()
        sleep(1)
        snap("stats_scroll_1")

        app.swipeUp()
        sleep(1)
        snap("stats_scroll_2")

        app.swipeUp()
        sleep(1)
        snap("stats_scroll_3")

        app.swipeUp()
        sleep(1)
        snap("stats_scroll_4")

        // 一番上に戻る
        app.swipeDown()
        sleep(1)
        app.swipeDown()
        sleep(1)
        app.swipeDown()
        sleep(1)
        app.swipeDown()
        sleep(1)

        // シェアボタンを試す
        let shareBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'share' OR label CONTAINS 'シェア' OR label CONTAINS 'square.and.arrow.up'")).firstMatch
        if shareBtn.waitForExistence(timeout: 3) && shareBtn.isHittable {
            shareBtn.tap()
            sleep(2)
            snap("stats_share_sheet")

            // 閉じる
            let closeShare = app.buttons.matching(NSPredicate(format: "label CONTAINS '閉じる' OR label CONTAINS 'close'")).firstMatch
            if closeShare.waitForExistence(timeout: 3) && closeShare.isHittable {
                closeShare.tap()
                sleep(1)
            }
        }

        // =============================================
        // Phase 5: 設定タブ
        // =============================================

        tapTab("設定")
        snap("settings_top")

        // テーマ切り替え
        let lavenderSetting = app.staticTexts["Lavender"]
        if lavenderSetting.waitForExistence(timeout: 3) && lavenderSetting.isHittable {
            lavenderSetting.tap()
            sleep(1)
            snap("settings_theme_lavender")
        }

        let monoGold = app.staticTexts["Mono Gold"]
        if monoGold.waitForExistence(timeout: 2) && monoGold.isHittable {
            monoGold.tap()
            sleep(1)
            snap("settings_theme_monogold")
        }

        let forest = app.staticTexts["Forest"]
        if forest.waitForExistence(timeout: 2) && forest.isHittable {
            forest.tap()
            sleep(1)
            snap("settings_theme_forest")
        }

        // Oceanに戻す
        let oceanSetting = app.staticTexts["Ocean"]
        if oceanSetting.waitForExistence(timeout: 2) && oceanSetting.isHittable {
            oceanSetting.tap()
            sleep(1)
        }

        // スクロールして設定の続きを見る
        app.swipeUp()
        sleep(1)
        snap("settings_scroll_1")

        app.swipeUp()
        sleep(1)
        snap("settings_scroll_2")

        app.swipeUp()
        sleep(1)
        snap("settings_scroll_3")

        app.swipeUp()
        sleep(1)
        snap("settings_scroll_4")

        // エクスポートボタンを探す
        let exportBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'エクスポート' OR label CONTAINS 'CSV'")).firstMatch
        if exportBtn.waitForExistence(timeout: 3) && exportBtn.isHittable {
            exportBtn.tap()
            sleep(2)
            snap("settings_export")

            // シェアシートが出たら閉じる
            let closeExport = app.buttons["Close"]
            if closeExport.waitForExistence(timeout: 3) {
                closeExport.tap()
                sleep(1)
            }
        }

        // 一番上に戻る
        app.swipeDown()
        sleep(1)
        app.swipeDown()
        sleep(1)
        app.swipeDown()
        sleep(1)
        app.swipeDown()
        sleep(1)

        // タグ管理を試す
        let tagManage = app.buttons.matching(NSPredicate(format: "label CONTAINS 'タグ' AND label CONTAINS '管理'")).firstMatch
        if tagManage.waitForExistence(timeout: 3) && tagManage.isHittable {
            tagManage.tap()
            sleep(2)
            snap("tag_management")

            // カスタムタグ追加を試す
            let addTag = app.buttons.matching(NSPredicate(format: "label CONTAINS 'カスタムタグ' OR label CONTAINS '追加'")).firstMatch
            if addTag.waitForExistence(timeout: 3) && addTag.isHittable {
                addTag.tap()
                sleep(1)
                snap("tag_add_sheet")

                // 名前を入力
                let nameField = app.textFields.firstMatch
                if nameField.waitForExistence(timeout: 2) {
                    nameField.tap()
                    nameField.typeText("テスト")
                    sleep(1)
                    snap("tag_add_typed")

                    // 追加ボタン
                    let addBtn = app.buttons["追加"]
                    if addBtn.waitForExistence(timeout: 2) && addBtn.isEnabled {
                        addBtn.tap()
                        sleep(1)
                        snap("tag_added")
                    } else {
                        // キャンセル
                        let cancelBtn = app.buttons["キャンセル"]
                        if cancelBtn.exists { cancelBtn.tap() }
                        sleep(1)
                    }
                }
            }

            // 戻る
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // =============================================
        // Phase 6: 横画面テスト（各タブ）
        // =============================================

        // 記録タブ横画面
        tapTab("記録")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        snap("main_landscape")

        // グラフタブ横画面
        tapTab("グラフ")
        sleep(2)
        snap("graph_landscape")

        // 統計タブ横画面
        tapTab("統計")
        sleep(2)
        snap("stats_landscape")

        // 設定タブ横画面
        tapTab("設定")
        sleep(2)
        snap("settings_landscape")

        // 縦画面に戻す
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        snap("final_portrait")
    }

    // MARK: - ヘルパー

    private func findElement(app: XCUIApplication, label: String) -> XCUIElement? {
        let staticText = app.staticTexts[label]
        if staticText.waitForExistence(timeout: 3) && staticText.isHittable {
            return staticText
        }
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 2) && button.isHittable {
            return button
        }
        // predicate search
        let pred = NSPredicate(format: "label CONTAINS %@", label)
        let match = app.buttons.matching(pred).firstMatch
        if match.waitForExistence(timeout: 2) && match.isHittable {
            return match
        }
        return nil
    }

    // MARK: - 全画面チャート回転テスト（既存）

    @MainActor
    func testFullscreenChartRotation() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(2)

        addScreenshot(name: "00_launch")

        let graphTab = app.staticTexts["グラフ"]
        if graphTab.waitForExistence(timeout: 5) {
            graphTab.tap()
        } else {
            let graphButton = app.buttons["グラフ"]
            if graphButton.waitForExistence(timeout: 3) {
                graphButton.tap()
            }
        }
        sleep(2)
        addScreenshot(name: "01_graph_tab")

        var foundFullscreen = false
        let buttonsQuery = app.buttons
        for i in 0..<buttonsQuery.count {
            let btn = buttonsQuery.element(boundBy: i)
            if btn.exists && btn.isHittable {
                let label = btn.label
                if label.contains("arrow") || label.contains("expand") || label.contains("fullscreen") || label.contains("全画面") {
                    btn.tap()
                    foundFullscreen = true
                    break
                }
            }
        }

        if !foundFullscreen {
            let coordinate = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.14))
            coordinate.tap()
        }
        sleep(2)
        addScreenshot(name: "02_fullscreen_portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        addScreenshot(name: "03_fullscreen_landscape")

        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        addScreenshot(name: "04_fullscreen_back_to_portrait")

        XCUIDevice.shared.orientation = .landscapeRight
        sleep(3)
        addScreenshot(name: "05_fullscreen_landscape_right")

        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        addScreenshot(name: "06_final_portrait")
    }

    private func addScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let data = screenshot.pngRepresentation as? Data ?? screenshot.image.pngData() {
            let url = URL(fileURLWithPath: "/tmp/nami_uitest_\(name).png")
            try? data.write(to: url)
        }
    }
}

extension XCUIScreenshot {
    var pngRepresentation: Data? {
        return image.pngData()
    }
}
