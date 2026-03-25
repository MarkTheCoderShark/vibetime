import Foundation
import SwiftUI
import ServiceManagement

struct TrackedApp: Codable, Identifiable, Hashable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
}

class AppSettings: ObservableObject {
    @Published var trackedApps: [TrackedApp] {
        didSet { save() }
    }

    @Published var idleTimeout: TimeInterval {
        didSet { save() }
    }

    @Published var focusStreakThreshold: TimeInterval {
        didSet { save() }
    }

    @Published var dailyGoalHours: Double {
        didSet { save() }
    }

    @Published var showDailyWrap: Bool {
        didSet { save() }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            save()
            updateLaunchAtLogin()
        }
    }

    private let defaults = UserDefaults.standard
    private let trackedAppsKey = "trackedApps"
    private let idleTimeoutKey = "idleTimeout"
    private let focusThresholdKey = "focusStreakThreshold"
    private let dailyGoalKey = "dailyGoalHours"
    private let dailyWrapKey = "showDailyWrap"
    private let launchAtLoginKey = "launchAtLogin"

    // Default tracked apps — common dev tools
    static let defaultApps: [TrackedApp] = [
        TrackedApp(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
        TrackedApp(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        TrackedApp(bundleID: "com.apple.Terminal", name: "Terminal"),
        TrackedApp(bundleID: "com.microsoft.VSCode", name: "VS Code"),
        TrackedApp(bundleID: "com.googlecode.iterm2", name: "iTerm2"),
    ]

    init() {
        // Load tracked apps
        if let data = defaults.data(forKey: trackedAppsKey),
           let apps = try? JSONDecoder().decode([TrackedApp].self, from: data) {
            self.trackedApps = apps
        } else {
            self.trackedApps = Self.defaultApps
        }

        self.idleTimeout = defaults.object(forKey: idleTimeoutKey) as? TimeInterval ?? 300
        self.focusStreakThreshold = defaults.object(forKey: focusThresholdKey) as? TimeInterval ?? 30
        self.dailyGoalHours = defaults.object(forKey: dailyGoalKey) as? Double ?? 0
        self.showDailyWrap = defaults.object(forKey: dailyWrapKey) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: launchAtLoginKey) as? Bool ?? false
    }

    private func save() {
        if let data = try? JSONEncoder().encode(trackedApps) {
            defaults.set(data, forKey: trackedAppsKey)
        }
        defaults.set(idleTimeout, forKey: idleTimeoutKey)
        defaults.set(focusStreakThreshold, forKey: focusThresholdKey)
        defaults.set(dailyGoalHours, forKey: dailyGoalKey)
        defaults.set(showDailyWrap, forKey: dailyWrapKey)
        defaults.set(launchAtLogin, forKey: launchAtLoginKey)
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }

    func addApp(bundleID: String, name: String) {
        guard !trackedApps.contains(where: { $0.bundleID == bundleID }) else { return }
        trackedApps.append(TrackedApp(bundleID: bundleID, name: name))
    }

    func removeApp(bundleID: String) {
        trackedApps.removeAll { $0.bundleID == bundleID }
    }
}
