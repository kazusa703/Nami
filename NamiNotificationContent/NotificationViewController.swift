//
//  NotificationViewController.swift
//  NamiNotificationContent
//
//  Rich notification UI: score slider + save button for mood recording
//

import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI
import WidgetKit

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var hostingController: UIHostingController<NotificationContentView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let contentView = NotificationContentView()
        let hosting = UIHostingController(rootView: contentView)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting

        preferredContentSize = CGSize(width: view.bounds.width, height: 280)
    }

    func didReceive(_: UNNotification) {
        // Notification received — UI is already set up
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        if response.actionIdentifier == "OPEN_APP" {
            completion(.dismissAndForwardAction)
        } else {
            completion(.doNotDismiss)
        }
    }
}

// MARK: - SwiftUI Content View

struct NotificationContentView: View {
    @State private var sliderValue: Double = 5
    @State private var saved = false

    private let appGroupID = "group.com.imai.Nami"

    private var maxScore: Int {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let stored = defaults.integer(forKey: "scoreRangeMax")
        return stored > 0 ? stored : 10
    }

    private var minScore: Int {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let stored = defaults.integer(forKey: "scoreRangeMin")
        if stored == 0 {
            let rangeKey = defaults.string(forKey: "scoreRange") ?? ""
            if rangeKey.hasPrefix("neg") { return -maxScore }
            return 1
        }
        return stored
    }

    private var midValue: Double {
        Double(minScore + maxScore) / 2.0
    }

    var body: some View {
        VStack(spacing: 16) {
            if saved {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("記録しました")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Score display
                Text("\(Int(sliderValue.rounded()))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                // Slider
                VStack(spacing: 4) {
                    Slider(
                        value: $sliderValue,
                        in: Double(minScore) ... Double(maxScore),
                        step: 1
                    )
                    .tint(.blue)

                    HStack {
                        Text("\(minScore)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(maxScore)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)

                // Save button
                Button {
                    saveScore()
                } label: {
                    Text("記録する")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .animation(.spring(response: 0.3), value: saved)
        .onAppear {
            sliderValue = midValue.rounded()
        }
    }

    private func saveScore() {
        let score = Int(sliderValue.rounded())
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

        // Write to pending records queue
        let record: [String: Any] = [
            "score": score,
            "maxScore": maxScore,
            "scoreRangeMin": minScore,
            "createdAt": Date.now.timeIntervalSince1970,
            "id": UUID().uuidString,
            "source": "notification",
        ]

        var pending = defaults.array(forKey: "pendingNotificationRecords") as? [[String: Any]] ?? []
        pending.append(record)
        defaults.set(pending, forKey: "pendingNotificationRecords")

        // Update widget
        WidgetCenter.shared.reloadAllTimelines()

        // Show success
        withAnimation {
            saved = true
        }
    }
}
