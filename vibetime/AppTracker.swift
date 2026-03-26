import Foundation
import AppKit
import Combine
import UserNotifications

struct AppSession: Codable, Identifiable {
    let id: UUID
    let bundleID: String
    let appName: String
    var activeTime: TimeInterval
    var runningTime: TimeInterval
    var contextSwitches: Int
    var longestFocusStreak: TimeInterval
    var currentFocusStreak: TimeInterval
    var isRunning: Bool
    var isActive: Bool
    var lastActivated: Date?
    var lastLaunched: Date?

    init(bundleID: String, appName: String) {
        self.id = UUID()
        self.bundleID = bundleID
        self.appName = appName
        self.activeTime = 0
        self.runningTime = 0
        self.contextSwitches = 0
        self.longestFocusStreak = 0
        self.currentFocusStreak = 0
        self.isRunning = false
        self.isActive = false
        self.lastActivated = nil
        self.lastLaunched = nil
    }
}

struct DayRecord: Codable {
    let date: String
    var sessions: [String: AppSession] // keyed by bundleID
    var totalContextSwitches: Int
    var sessionStartTime: Date?
}

class AppTracker: ObservableObject {
    @Published var sessions: [String: AppSession] = [:]
    @Published var totalContextSwitches: Int = 0
    @Published var sessionStartTime: Date?
    @Published var isAnyTrackedAppActive: Bool = false

    var onStateChange: ((Bool) -> Void)?

    private var trackedBundleIDs: Set<String> = []
    private var currentActiveBundle: String?
    private var lastTrackedBundle: String?
    private var idleTimer: Timer?
    private var tickTimer: Timer?
    private let idleThreshold: TimeInterval = 300 // 5 minutes
    private var isIdle = false
    private var sleepTime: Date?
    private let sessionGapThreshold: TimeInterval = 1800 // 30 minutes
    private let storage = Storage()

    private var currentDateKey: String = Storage.todayKey()
    private var observers: [NSObjectProtocol] = []

    func loadTrackedBundleIDs(_ ids: [String]) {
        trackedBundleIDs = Set(ids)
        currentDateKey = Storage.todayKey()

        // Load today's saved data
        if let record = storage.loadToday() {
            sessions = record.sessions
            totalContextSwitches = record.totalContextSwitches
            sessionStartTime = record.sessionStartTime

            // Guard against stale data that leaked across a day boundary
            let midnight = Calendar.current.startOfDay(for: Date())
            let maxPossible = Date().timeIntervalSince(midnight)
            let hasStaleData = sessions.values.contains {
                $0.runningTime > maxPossible || $0.activeTime > maxPossible
            }
            if hasStaleData {
                sessions = [:]
                totalContextSwitches = 0
                sessionStartTime = nil
            }
        }

        // Check what's already running
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  trackedBundleIDs.contains(bundleID) else { continue }

            if sessions[bundleID] == nil {
                let name = app.localizedName ?? bundleID
                sessions[bundleID] = AppSession(bundleID: bundleID, appName: name)
            }
            sessions[bundleID]?.isRunning = true
            sessions[bundleID]?.lastLaunched = sessions[bundleID]?.lastLaunched ?? Date()

            if sessionStartTime == nil {
                sessionStartTime = Date()
            }
        }

        // Check current frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontmost.bundleIdentifier,
           trackedBundleIDs.contains(bundleID) {
            sessions[bundleID]?.isActive = true
            sessions[bundleID]?.lastActivated = Date()
            currentActiveBundle = bundleID
            isAnyTrackedAppActive = true
        }
    }

    func start() {
        let ws = NSWorkspace.shared
        let nc = ws.notificationCenter

        // App activated (became frontmost)
        let activateObs = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            self.handleAppActivated(bundleID: bundleID, appName: app.localizedName ?? bundleID)
        }

        // App deactivated (lost frontmost)
        let deactivateObs = nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            self.handleAppDeactivated(bundleID: bundleID)
        }

        // App launched
        let launchObs = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  self.trackedBundleIDs.contains(bundleID) else { return }
            self.handleAppLaunched(bundleID: bundleID, appName: app.localizedName ?? bundleID)
        }

        // App terminated
        let terminateObs = nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  self.trackedBundleIDs.contains(bundleID) else { return }
            self.handleAppTerminated(bundleID: bundleID)
        }

        // Sleep/wake — flush time on sleep, re-anchor on wake
        let sleepObs = nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep()
        }

        let wakeObs = nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWake()
        }

        observers = [activateObs, deactivateObs, launchObs, terminateObs, sleepObs, wakeObs]

        // Tick timer — updates running time for all running apps once per minute
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Idle detection timer
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    func stop() {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
        tickTimer?.invalidate()
        idleTimer?.invalidate()
    }

    // MARK: - Event Handlers

    private func handleAppActivated(bundleID: String, appName: String) {
        guard trackedBundleIDs.contains(bundleID) else {
            // Switched to a non-tracked app — mark we left a tracked context
            if currentActiveBundle != nil {
                lastTrackedBundle = currentActiveBundle
                currentActiveBundle = nil
                isAnyTrackedAppActive = false
                onStateChange?(false)
            }
            return
        }

        // Count context switch:
        // - From one tracked app to a different tracked app
        // - From a tracked app through non-tracked apps back to same or different tracked app
        let previous = currentActiveBundle ?? lastTrackedBundle
        if let previous = previous, previous != bundleID {
            totalContextSwitches += 1
            if var prevSession = sessions[previous] {
                prevSession.currentFocusStreak = 0
                sessions[previous] = prevSession
            }
        } else if let previous = previous, previous == bundleID, currentActiveBundle == nil {
            // Came back to the same tracked app after leaving — still a context switch
            totalContextSwitches += 1
        }
        lastTrackedBundle = nil

        if sessions[bundleID] == nil {
            sessions[bundleID] = AppSession(bundleID: bundleID, appName: appName)
        }

        sessions[bundleID]?.isActive = true
        sessions[bundleID]?.lastActivated = Date()
        currentActiveBundle = bundleID
        isAnyTrackedAppActive = true
        isIdle = false
        onStateChange?(true)

        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        save()
    }

    private func handleAppDeactivated(bundleID: String) {
        guard trackedBundleIDs.contains(bundleID),
              var session = sessions[bundleID] else { return }

        if let lastActivated = session.lastActivated {
            let elapsed = Date().timeIntervalSince(lastActivated)
            if !isIdle {
                session.activeTime += elapsed
                session.currentFocusStreak += elapsed
                if session.currentFocusStreak > session.longestFocusStreak {
                    session.longestFocusStreak = session.currentFocusStreak
                }
            }
        }

        session.isActive = false
        session.lastActivated = nil
        sessions[bundleID] = session

        save()
    }

    private func handleAppLaunched(bundleID: String, appName: String) {
        if sessions[bundleID] == nil {
            sessions[bundleID] = AppSession(bundleID: bundleID, appName: appName)
        }
        sessions[bundleID]?.isRunning = true
        sessions[bundleID]?.lastLaunched = Date()

        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        onStateChange?(isAnyTrackedAppActive)
        save()
    }

    private func handleAppTerminated(bundleID: String) {
        guard var session = sessions[bundleID] else { return }

        // Finalize running time
        if let lastLaunched = session.lastLaunched {
            session.runningTime += Date().timeIntervalSince(lastLaunched)
        }

        // Finalize active time if it was still active
        if session.isActive, let lastActivated = session.lastActivated {
            let elapsed = Date().timeIntervalSince(lastActivated)
            if !isIdle {
                session.activeTime += elapsed
            }
        }

        session.isRunning = false
        session.isActive = false
        session.lastLaunched = nil
        session.lastActivated = nil
        sessions[bundleID] = session

        if currentActiveBundle == bundleID {
            currentActiveBundle = nil
            isAnyTrackedAppActive = false
        }

        // Check if any tracked app is still running
        let anyRunning = sessions.values.contains { $0.isRunning }
        if !anyRunning {
            sendDailyWrapNotification()
        }

        onStateChange?(isAnyTrackedAppActive)
        save()
    }

    // MARK: - Sleep/Wake

    private func handleSleep() {
        let now = Date()
        sleepTime = now

        for (bundleID, var session) in sessions {
            // Flush running time up to the moment of sleep
            if session.isRunning, let lastLaunched = session.lastLaunched {
                session.runningTime += now.timeIntervalSince(lastLaunched)
                session.lastLaunched = nil
            }

            // Flush active time up to the moment of sleep
            if session.isActive, let lastActivated = session.lastActivated, !isIdle {
                let elapsed = now.timeIntervalSince(lastActivated)
                session.activeTime += elapsed
                session.currentFocusStreak += elapsed
                if session.currentFocusStreak > session.longestFocusStreak {
                    session.longestFocusStreak = session.currentFocusStreak
                }
                session.lastActivated = nil
            }

            sessions[bundleID] = session
        }

        save()
    }

    private func handleWake() {
        let now = Date()

        checkDayBoundary()

        // If the gap since sleep exceeds the threshold, start a new session
        if let sleepTime = sleepTime {
            let gap = now.timeIntervalSince(sleepTime)
            if gap > sessionGapThreshold {
                sessionStartTime = now
                // Reset focus streaks — new work block
                for (bundleID, var session) in sessions {
                    session.currentFocusStreak = 0
                    sessions[bundleID] = session
                }
            }
        }
        sleepTime = nil

        // Re-anchor timestamps so the next tick doesn't count the sleep period
        for (bundleID, var session) in sessions {
            if session.isRunning {
                session.lastLaunched = now
            }
            if session.isActive {
                session.lastActivated = now
            }
            sessions[bundleID] = session
        }

        save()
    }

    // MARK: - Day Boundary

    private func checkDayBoundary() {
        let todayKey = Storage.todayKey()
        guard todayKey != currentDateKey else { return }

        let now = Date()

        // Flush current active/running time into the old day's totals
        for (bundleID, var session) in sessions {
            if session.isRunning, let lastLaunched = session.lastLaunched {
                session.runningTime += now.timeIntervalSince(lastLaunched)
                session.lastLaunched = now
            }
            if session.isActive, let lastActivated = session.lastActivated, !isIdle {
                let elapsed = now.timeIntervalSince(lastActivated)
                session.activeTime += elapsed
                session.currentFocusStreak += elapsed
                if session.currentFocusStreak > session.longestFocusStreak {
                    session.longestFocusStreak = session.currentFocusStreak
                }
                session.lastActivated = now
            }
            sessions[bundleID] = session
        }

        // Save final snapshot to the old day's file
        let oldRecord = DayRecord(
            date: currentDateKey,
            sessions: sessions,
            totalContextSwitches: totalContextSwitches,
            sessionStartTime: sessionStartTime
        )
        storage.saveDay(oldRecord)

        // Reset for the new day
        currentDateKey = todayKey
        totalContextSwitches = 0
        let anyRunning = sessions.values.contains { $0.isRunning }
        sessionStartTime = anyRunning ? now : nil

        // Keep running/active apps but zero out accumulated time
        var fresh: [String: AppSession] = [:]
        for (bundleID, session) in sessions where session.isRunning || session.isActive {
            var s = AppSession(bundleID: bundleID, appName: session.appName)
            s.isRunning = session.isRunning
            s.isActive = session.isActive
            if session.isRunning { s.lastLaunched = now }
            if session.isActive { s.lastActivated = now }
            fresh[bundleID] = s
        }
        sessions = fresh

        save()
    }

    // MARK: - Tick (updates running time for live apps)

    private func tick() {
        checkDayBoundary()

        let now = Date()
        for (bundleID, var session) in sessions {
            if session.isRunning, let lastLaunched = session.lastLaunched {
                session.runningTime += now.timeIntervalSince(lastLaunched)
                session.lastLaunched = now
            }
            if session.isActive, let lastActivated = session.lastActivated, !isIdle {
                let elapsed = now.timeIntervalSince(lastActivated)
                session.activeTime += elapsed
                session.currentFocusStreak += elapsed
                if session.currentFocusStreak > session.longestFocusStreak {
                    session.longestFocusStreak = session.currentFocusStreak
                }
                session.lastActivated = now
            }
            sessions[bundleID] = session
        }
        save()
    }

    // MARK: - Idle Detection

    private func checkIdle() {
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let minIdle = min(idleTime, keyIdle)

        if minIdle > idleThreshold && !isIdle {
            isIdle = true
            // Freeze active time accumulation — the tick() method checks isIdle
        } else if minIdle <= idleThreshold && isIdle {
            isIdle = false
            // Re-anchor the lastActivated time so we don't count idle period
            if let bundleID = currentActiveBundle {
                sessions[bundleID]?.lastActivated = Date()
            }
        }
    }

    // MARK: - Computed Properties

    var totalActiveTime: TimeInterval {
        sessions.values.reduce(0) { $0 + $1.activeTime + currentActiveElapsed(for: $1) }
    }

    var totalRunningTime: TimeInterval {
        sessions.values.reduce(0) { $0 + $1.runningTime + currentRunningElapsed(for: $1) }
    }

    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var bestFocusStreak: TimeInterval {
        sessions.values.map { max($0.longestFocusStreak, $0.currentFocusStreak) }.max() ?? 0
    }

    func activeTime(for bundleID: String) -> TimeInterval {
        guard let session = sessions[bundleID] else { return 0 }
        return session.activeTime + currentActiveElapsed(for: session)
    }

    func runningTime(for bundleID: String) -> TimeInterval {
        guard let session = sessions[bundleID] else { return 0 }
        return session.runningTime + currentRunningElapsed(for: session)
    }

    private func currentActiveElapsed(for session: AppSession) -> TimeInterval {
        guard session.isActive, !isIdle, let last = session.lastActivated else { return 0 }
        return Date().timeIntervalSince(last)
    }

    private func currentRunningElapsed(for session: AppSession) -> TimeInterval {
        guard session.isRunning, let last = session.lastLaunched else { return 0 }
        return Date().timeIntervalSince(last)
    }

    // MARK: - Persistence

    private func save() {
        let record = DayRecord(
            date: Storage.todayKey(),
            sessions: sessions,
            totalContextSwitches: totalContextSwitches,
            sessionStartTime: sessionStartTime
        )
        storage.saveDay(record)
    }

    func weekHistory() -> [DayRecord] {
        storage.loadWeek()
    }

    // MARK: - Daily Wrap Notification

    private func sendDailyWrapNotification() {
        let total = totalActiveTime
        let streak = bestFocusStreak
        let appCount = sessions.values.filter { $0.activeTime > 0 }.count

        let content = UNMutableNotificationContent()
        content.title = "vibetime — Daily Wrap"
        content.body = "Today's vibe: \(formatTime(total)) active across \(appCount) app\(appCount == 1 ? "" : "s"). Best focus: \(formatTime(streak))."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "daily-wrap", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
