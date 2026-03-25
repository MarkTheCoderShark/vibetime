import SwiftUI

// MARK: - Popover Settings (inline in the dropdown)

struct PopoverSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var showSettings: Bool
    @State private var tab: SettingsTab = .general

    enum SettingsTab {
        case general, apps
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Text("Back")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showSettings = false
                        }
                    }

                Spacer()

                Text("Settings")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer()

                // Invisible spacer to balance the back button
                Text("Back")
                    .font(.system(size: 12))
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .opacity(0.3)
                .padding(.horizontal, 12)

            // Tab picker
            HStack(spacing: 0) {
                tabButton("General", tab: .general)
                tabButton("Apps", tab: .apps)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Content
            ScrollView {
                if tab == .general {
                    generalContent
                } else {
                    appsContent
                }
            }
            .padding(.top, 8)
        }
    }

    private func tabButton(_ title: String, tab: SettingsTab) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundColor(self.tab == tab ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(self.tab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.tab = tab
                }
            }
    }

    // MARK: - General

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsToggle("Launch at Login", isOn: $settings.launchAtLogin)
            settingsToggle("Daily Wrap Notification", isOn: $settings.showDailyWrap)

            Divider().opacity(0.3)

            Text("Idle Timeout")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Picker("", selection: $settings.idleTimeout) {
                Text("2 min").tag(TimeInterval(120))
                Text("5 min").tag(TimeInterval(300))
                Text("10 min").tag(TimeInterval(600))
                Text("15 min").tag(TimeInterval(900))
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Focus Streak Break")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Picker("", selection: $settings.focusStreakThreshold) {
                Text("15s").tag(TimeInterval(15))
                Text("30s").tag(TimeInterval(30))
                Text("1m").tag(TimeInterval(60))
                Text("2m").tag(TimeInterval(120))
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider().opacity(0.3)

            HStack {
                Text("Daily Goal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(settings.dailyGoalHours > 0 ? String(format: "%.1fh", settings.dailyGoalHours) : "Off")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $settings.dailyGoalHours, in: 0...12, step: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Apps

    @State private var newBundleID = ""
    @State private var newAppName = ""

    private var appsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current tracked apps
            ForEach(settings.trackedApps) { app in
                HStack(spacing: 8) {
                    appIcon(for: app.bundleID)
                        .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.name)
                            .font(.system(size: 12, weight: .medium))
                        Text(app.bundleID)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.system(size: 14))
                        .onTapGesture {
                            settings.removeApp(bundleID: app.bundleID)
                        }
                }
                .padding(.vertical, 2)
            }

            Divider().opacity(0.3)

            // Add from running apps
            Text("Add from running apps")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            let available = availableRunningApps()
            if available.isEmpty {
                Text("No new apps to add")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(available, id: \.bundleIdentifier) { app in
                        HStack(spacing: 4) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(app.localizedName ?? "Unknown")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                        .onTapGesture {
                            if let bid = app.bundleIdentifier {
                                settings.addApp(bundleID: bid, name: app.localizedName ?? bid)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private func availableRunningApps() -> [NSRunningApplication] {
        let tracked = Set(settings.trackedApps.map { $0.bundleID })
        return NSWorkspace.shared.runningApplications
            .filter { app in
                guard let bid = app.bundleIdentifier else { return false }
                return app.activationPolicy == .regular && !tracked.contains(bid)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
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
}

// MARK: - Flow Layout for app chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
