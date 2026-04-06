import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var tracker: AppTracker
    @EnvironmentObject var settings: AppSettings
    @State private var refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tick: Bool = false
    @State private var showSettings = false
    @State private var showSharePicker = false
    @State private var showCopiedFeedback = false

    var body: some View {
        if showSettings {
            PopoverSettingsView(showSettings: $showSettings)
                .environmentObject(settings)
                .frame(width: 320)
        } else if showSharePicker {
            ShareRangePickerView(
                showSharePicker: $showSharePicker,
                showCopiedFeedback: $showCopiedFeedback,
                tracker: tracker
            )
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEEE" // single-letter day name

        // Use live data for today, saved data for previous days
        let totals: [Double] = week.enumerated().map { (i, record) in
            if i == week.count - 1 { return tracker.totalActiveTime }
            return record.sessions.values.reduce(0.0) { $0 + $1.activeTime }
        }

        let dayLabels: [String] = week.map { record in
            if let date = dateFormatter.date(from: record.date) {
                return dayFormatter.string(from: date)
            }
            return "?"
        }

        let weekTotal = totals.reduce(0, +)
        let daysWithData = totals.filter { $0 > 0 }.count
        let avgPerDay = daysWithData > 0 ? weekTotal / Double(daysWithData) : 0

        let weekBestFocus: TimeInterval = week.enumerated().map { (i, record) in
            if i == week.count - 1 { return tracker.bestFocusStreak }
            return record.sessions.values.map(\.longestFocusStreak).max() ?? 0
        }.max() ?? 0

        let maxTotal = totals.max() ?? 1

        return VStack(spacing: 6) {
            // Week header with total
            HStack {
                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(weekTotal))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .id(tick)
            }

            // Sparkline bars
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

                        Text(dayLabels[i])
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Weekly summary
            HStack(spacing: 4) {
                Text("Avg")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(formatTime(avgPerDay))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))

                Text("·")
                    .foregroundColor(.secondary)

                Text("Best focus")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(formatTime(weekBestFocus))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .id(tick)
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

                Menu {
                    Button("Today") { shareCard() }

                    Button("This Week") { shareRollingWeek() }

                    Button("Last Week") { shareLastWeek() }

                    Divider()

                    Button("Custom Range...") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showSharePicker = true
                        }
                    }
                } label: {
                    Label(showCopiedFeedback ? "Saved!" : "Share", systemImage: showCopiedFeedback ? "checkmark" : "square.and.arrow.up")
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundColor(showCopiedFeedback ? .green : .secondary)
                }
                .menuStyle(.borderlessButton)
                .glassEffect(.regular, in: .capsule)

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

    // MARK: - Share Helpers

    private func showCopiedFeedbackBriefly() {
        withAnimation { showCopiedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedFeedback = false }
        }
    }

    private func shareCard() {
        let week = tracker.weekHistory()
        let weekTotals = week.map { record in
            record.sessions.values.reduce(0.0) { $0 + $1.activeTime }
        }

        let allSessions = Array(tracker.sessions.values)
        let success = saveAndCopyShareCard(
            sessions: allSessions,
            totalActive: tracker.totalActiveTime,
            totalRunning: tracker.totalRunningTime,
            sessionDuration: tracker.sessionDuration,
            bestStreak: tracker.bestFocusStreak,
            contextSwitches: tracker.totalContextSwitches,
            weekTotals: weekTotals,
            previousWeekTotal: 0
        )

        if success { showCopiedFeedbackBriefly() }
    }

    private func shareRollingWeek() {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: end)!
        shareRange(from: start, to: end)
    }

    private func shareLastWeek() {
        let calendar = Calendar.current
        // Find the most recent Monday (start of this week), then go back 7 days for last week
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon
        let daysSinceMonday = (weekday + 5) % 7 // 0=Mon, 1=Tue, ...
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
        let lastSunday = calendar.date(byAdding: .day, value: -1, to: thisMonday)!
        shareRange(from: lastMonday, to: lastSunday)
    }

    private func shareRange(from startDate: Date, to endDate: Date) {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let startKey = keyFormatter.string(from: startDate)
        let endKey = keyFormatter.string(from: endDate)
        let todayKey = Storage.todayKey()

        let storage = Storage()
        let records = storage.loadDays(from: startKey, to: endKey)

        let daySessions: [[AppSession]] = records.map { record in
            if record.date == todayKey {
                return Array(tracker.sessions.values)
            }
            return Array(record.sessions.values)
        }

        let dayTotals: [TimeInterval] = records.map { record in
            if record.date == todayKey { return tracker.totalActiveTime }
            return record.sessions.values.reduce(0.0) { $0 + $1.activeTime }
        }

        let totalActive = dayTotals.reduce(0, +)

        let totalRunning: TimeInterval = records.reduce(0.0) { acc, record in
            if record.date == todayKey { return acc + tracker.totalRunningTime }
            return acc + record.sessions.values.reduce(0.0) { $0 + $1.runningTime }
        }

        let bestStreak: TimeInterval = records.map { record in
            if record.date == todayKey { return tracker.bestFocusStreak }
            return record.sessions.values.map(\.longestFocusStreak).max() ?? 0
        }.max() ?? 0

        let totalSwitches: Int = records.reduce(0) { acc, record in
            if record.date == todayKey { return acc + tracker.totalContextSwitches }
            return acc + record.totalContextSwitches
        }

        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "MMM d, yyyy"
        let weekLabel = "\(labelFormatter.string(from: startDate)) – \(yearFormatter.string(from: endDate))"

        let fileSuffix: String = {
            let f = DateFormatter()
            f.dateFormat = "MMMd"
            return "\(f.string(from: startDate))-\(f.string(from: endDate))"
        }()

        let dayDates = records.map(\.date)

        let success = saveAndCopyWeekShareCard(
            daySessions: daySessions,
            dayTotals: dayTotals,
            totalActive: totalActive,
            totalRunning: totalRunning,
            bestStreak: bestStreak,
            totalSwitches: totalSwitches,
            weekLabel: weekLabel,
            dayDates: dayDates,
            filenameSuffix: fileSuffix
        )

        if success { showCopiedFeedbackBriefly() }
    }

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

// MARK: - Share Range Picker

struct ShareRangePickerView: View {
    @Binding var showSharePicker: Bool
    @Binding var showCopiedFeedback: Bool
    @ObservedObject var tracker: AppTracker

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    private var earliestDate: Date {
        Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showSharePicker = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Text("Export Range")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)

            VStack(spacing: 14) {
                // Date pickers
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "From",
                        selection: $startDate,
                        in: earliestDate...endDate,
                        displayedComponents: .date
                    )
                    .font(.system(size: 12))

                    DatePicker(
                        "To",
                        selection: $endDate,
                        in: startDate...Date(),
                        displayedComponents: .date
                    )
                    .font(.system(size: 12))
                }

                // Preview stats
                let preview = previewStats()
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(formatTime(preview.totalActive))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        Text("Active")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(preview.days) day\(preview.days == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        Text("Range")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(preview.appsUsed)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        Text("Apps")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Share button
                Button {
                    exportRange()
                } label: {
                    Label(showCopiedFeedback ? "Saved!" : "Export & Copy", systemImage: showCopiedFeedback ? "checkmark" : "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private struct PreviewStats {
        let totalActive: TimeInterval
        let days: Int
        let appsUsed: Int
    }

    private func previewStats() -> PreviewStats {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = Storage.todayKey()

        let storage = Storage()
        let records = storage.loadDays(
            from: keyFormatter.string(from: startDate),
            to: keyFormatter.string(from: endDate)
        )

        var totalActive: TimeInterval = 0
        var appNames: Set<String> = []

        for record in records {
            if record.date == todayKey {
                totalActive += tracker.totalActiveTime
                for session in tracker.sessions.values where session.activeTime > 0 || session.isActive {
                    appNames.insert(session.appName)
                }
            } else {
                for session in record.sessions.values {
                    totalActive += session.activeTime
                    if session.activeTime > 0 { appNames.insert(session.appName) }
                }
            }
        }

        return PreviewStats(totalActive: totalActive, days: records.count, appsUsed: appNames.count)
    }

    private func exportRange() {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let startKey = keyFormatter.string(from: startDate)
        let endKey = keyFormatter.string(from: endDate)
        let todayKey = Storage.todayKey()

        let storage = Storage()
        let records = storage.loadDays(from: startKey, to: endKey)

        let daySessions: [[AppSession]] = records.map { record in
            if record.date == todayKey { return Array(tracker.sessions.values) }
            return Array(record.sessions.values)
        }

        let dayTotals: [TimeInterval] = records.map { record in
            if record.date == todayKey { return tracker.totalActiveTime }
            return record.sessions.values.reduce(0.0) { $0 + $1.activeTime }
        }

        let totalActive = dayTotals.reduce(0, +)

        let totalRunning: TimeInterval = records.reduce(0.0) { acc, record in
            if record.date == todayKey { return acc + tracker.totalRunningTime }
            return acc + record.sessions.values.reduce(0.0) { $0 + $1.runningTime }
        }

        let bestStreak: TimeInterval = records.map { record in
            if record.date == todayKey { return tracker.bestFocusStreak }
            return record.sessions.values.map(\.longestFocusStreak).max() ?? 0
        }.max() ?? 0

        let totalSwitches: Int = records.reduce(0) { acc, record in
            if record.date == todayKey { return acc + tracker.totalContextSwitches }
            return acc + record.totalContextSwitches
        }

        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "MMM d, yyyy"
        let weekLabel = "\(labelFormatter.string(from: startDate)) – \(yearFormatter.string(from: endDate))"

        let fileSuffix: String = {
            let f = DateFormatter()
            f.dateFormat = "MMMd"
            return "\(f.string(from: startDate))-\(f.string(from: endDate))"
        }()

        let dayDates = records.map(\.date)

        let success = saveAndCopyWeekShareCard(
            daySessions: daySessions,
            dayTotals: dayTotals,
            totalActive: totalActive,
            totalRunning: totalRunning,
            bestStreak: bestStreak,
            totalSwitches: totalSwitches,
            weekLabel: weekLabel,
            dayDates: dayDates,
            filenameSuffix: fileSuffix
        )

        if success {
            withAnimation { showCopiedFeedback = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopiedFeedback = false }
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        return String(format: "%dm", minutes)
    }
}
