import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var tracker: AppTracker
    @EnvironmentObject var settings: AppSettings
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tick: Bool = false
    @State private var showSettings = false

    var body: some View {
        if showSettings {
            PopoverSettingsView(showSettings: $showSettings)
                .environmentObject(settings)
                .frame(width: 320)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)

            // Column labels
            HStack(spacing: 0) {
                Spacer()
                Text("Active")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 52, alignment: .trailing)
                Text("Running")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 58, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            appList

            totalRow
                .padding(.horizontal, 16)
                .padding(.top, 6)

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            statsRow
                .padding(.horizontal, 16)
                .padding(.top, 10)

            weekSparkline
                .padding(.horizontal, 16)
                .padding(.top, 10)

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            footerRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 320)
        .onReceive(refreshTimer) { _ in
            tick.toggle()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("vibetime")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                HStack(spacing: 4) {
                    Circle()
                        .fill(tracker.isAnyTrackedAppActive ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(tracker.isAnyTrackedAppActive ? "Tracking" : "Idle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Session")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(formatTime(tracker.sessionDuration))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .id(tick)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - App List

    private var appList: some View {
        VStack(spacing: 6) {
            let sorted = sortedSessions()
            if sorted.isEmpty {
                Text("No tracked apps running")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(sorted, id: \.bundleID) { session in
                    appRow(session: session)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func appRow(session: AppSession) -> some View {
        let active = tracker.activeTime(for: session.bundleID)
        let running = tracker.runningTime(for: session.bundleID)
        let maxTime = maxActiveTime()
        let fraction = maxTime > 0 ? active / maxTime : 0

        return HStack(spacing: 8) {
            appIcon(for: session.bundleID)
                .frame(width: 20, height: 20)

            Text(session.appName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 4)

            // Active time bar + value
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(for: session).gradient)
                        .frame(width: max(3, geo.size.width * fraction), height: 6)
                }
            }
            .frame(width: 50, height: 6)

            Text(formatTime(active))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 52, alignment: .trailing)
                .id(tick)

            Text(formatTime(running))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .trailing)
                .id(tick)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Total Row

    private var totalRow: some View {
        HStack(spacing: 0) {
            Text("Total")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(formatTime(tracker.totalActiveTime))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 52, alignment: .trailing)
                .id(tick)

            Text(formatTime(tracker.totalRunningTime))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 58, alignment: .trailing)
                .id(tick)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                StatBadge(
                    icon: "bolt.fill",
                    label: "Focus",
                    value: formatTime(tracker.bestFocusStreak)
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 10))

                StatBadge(
                    icon: "arrow.triangle.swap",
                    label: "Switches",
                    value: "\(tracker.totalContextSwitches)"
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 10))

                if settings.dailyGoalHours > 0 {
                    let progress = tracker.totalActiveTime / (settings.dailyGoalHours * 3600)
                    StatBadge(
                        icon: "target",
                        label: "Goal",
                        value: "\(Int(min(progress, 1.0) * 100))%"
                    )
                    .glassEffect(.regular.tint(.green), in: .rect(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Week Sparkline

    private var weekSparkline: some View {
        let week = tracker.weekHistory()
        let totals = week.map { record in
            record.sessions.values.reduce(0.0) { $0 + $1.activeTime }
        }
        let maxTotal = totals.max() ?? 1
        let days = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                i == 6
                                    ? Color.accentColor.gradient
                                    : Color.accentColor.opacity(0.4).gradient
                            )
                            .frame(width: 28, height: max(4, CGFloat(totals[i] / maxTotal) * 32))
                            .frame(height: 32, alignment: .bottom)

                        Text(days[i])
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        GlassEffectContainer(spacing: 8) {
            HStack {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundColor(.secondary)
                    .glassEffect(.regular, in: .capsule)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showSettings = true
                        }
                    }

                Spacer()

                Label("Quit", systemImage: "power")
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundColor(.secondary)
                    .glassEffect(.regular, in: .capsule)
                    .onTapGesture {
                        NSApp.terminate(nil)
                    }
            }
        }
    }

    // MARK: - Helpers

    private func sortedSessions() -> [AppSession] {
        let activeSessions = tracker.sessions.values.filter { $0.isRunning || $0.activeTime > 0 || $0.runningTime > 0 }
        return activeSessions.sorted { a, b in
            tracker.activeTime(for: a.bundleID) > tracker.activeTime(for: b.bundleID)
        }
    }

    private func maxActiveTime() -> TimeInterval {
        sortedSessions().map { tracker.activeTime(for: $0.bundleID) }.max() ?? 1
    }

    private func barColor(for session: AppSession) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink]
        let index = abs(session.bundleID.hashValue) % colors.count
        return colors[index]
    }

    private func appIcon(for bundleID: String) -> some View {
        Group {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
}
