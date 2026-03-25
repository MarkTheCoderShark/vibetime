import SwiftUI
import AppKit

struct ShareCardView: View {
    let sessions: [AppSession]
    let totalActive: TimeInterval
    let totalRunning: TimeInterval
    let sessionDuration: TimeInterval
    let bestStreak: TimeInterval
    let contextSwitches: Int
    let weekTotals: [TimeInterval]
    let previousWeekTotal: TimeInterval

    private let cardWidth: CGFloat = 440
    private let cardHeight: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("vibetime")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(dateString())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            // Big number — total active time
            VStack(spacing: 6) {
                Text(formatTimeLarge(totalActive))
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Text("ACTIVE TODAY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.5)

                    if previousWeekTotal > 0 {
                        let currentWeekTotal = weekTotals.reduce(0, +)
                        let delta = currentWeekTotal - previousWeekTotal
                        let pct = (delta / previousWeekTotal) * 100
                        HStack(spacing: 3) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(String(format: "%.0f%% WoW", abs(pct)))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(delta >= 0 ? Color(red: 0.3, green: 0.85, blue: 0.45) : Color(red: 0.95, green: 0.35, blue: 0.35))
                    }
                }
            }
            .padding(.top, 20)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 28)
                .padding(.top, 20)

            // Positions (per-app breakdown)
            VStack(spacing: 0) {
                // Column headers
                HStack {
                    Text("APP")
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Text("ACTIVE")
                        .frame(width: 70, alignment: .trailing)
                    Text("RUNNING")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1)
                .padding(.bottom, 8)

                let sorted = sessions
                    .filter { $0.activeTime > 0 || $0.runningTime > 0 }
                    .sorted { $0.activeTime > $1.activeTime }

                ForEach(Array(sorted.prefix(5).enumerated()), id: \.offset) { index, session in
                    positionRow(session: session, index: index)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 28)
                .padding(.top, 12)

            // Stats row
            HStack(spacing: 0) {
                statCell(label: "SESSION", value: formatTimeCompact(sessionDuration))
                statCell(label: "FOCUS BEST", value: formatTimeCompact(bestStreak))
                statCell(label: "SWITCHES", value: "\(contextSwitches)")
                statCell(label: "RUNNING", value: formatTimeCompact(totalRunning))
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)

            // Weekly chart
            weeklyChart
                .padding(.horizontal, 28)
                .padding(.top, 16)

            Spacer()

            // Footer
            HStack {
                Text("vibetime")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
                Spacer()
                Text("github.com/MarkTheCoderShark/vibetime")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.12),
                            Color(red: 0.05, green: 0.05, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Position Row

    private func positionRow(session: AppSession, index: Int) -> some View {
        let maxActive = sessions.map(\.activeTime).max() ?? 1
        let fraction = session.activeTime / maxActive
        let colors: [Color] = [
            Color(red: 0.3, green: 0.6, blue: 1.0),
            Color(red: 0.6, green: 0.4, blue: 1.0),
            Color(red: 1.0, green: 0.55, blue: 0.2),
            Color(red: 0.3, green: 0.85, blue: 0.45),
            Color(red: 1.0, green: 0.4, blue: 0.5)
        ]
        let color = colors[index % colors.count]

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Color dot
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(session.appName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 90, alignment: .leading)
                    .lineLimit(1)

                // Mini bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.04))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.6))
                            .frame(width: max(2, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)

                Text(formatTimeCompact(session.activeTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 70, alignment: .trailing)

                Text(formatTimeCompact(session.runningTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Stat Cell

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let maxTotal = weekTotals.max() ?? 1
        let days = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                i == 6
                                    ? LinearGradient(colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.5, green: 0.4, blue: 1.0)], startPoint: .bottom, endPoint: .top)
                                    : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)], startPoint: .bottom, endPoint: .top)
                            )
                            .frame(height: max(3, CGFloat(weekTotals[i] / maxTotal) * 36))
                            .frame(height: 36, alignment: .bottom)

                        Text(days[i])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Helpers

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    private func formatTimeLarge(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }

    private func formatTimeCompact(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

// MARK: - Render to Image

@MainActor
func renderShareCard(
    sessions: [AppSession],
    totalActive: TimeInterval,
    totalRunning: TimeInterval,
    sessionDuration: TimeInterval,
    bestStreak: TimeInterval,
    contextSwitches: Int,
    weekTotals: [TimeInterval],
    previousWeekTotal: TimeInterval
) -> NSImage? {
    let view = ShareCardView(
        sessions: sessions,
        totalActive: totalActive,
        totalRunning: totalRunning,
        sessionDuration: sessionDuration,
        bestStreak: bestStreak,
        contextSwitches: contextSwitches,
        weekTotals: weekTotals,
        previousWeekTotal: previousWeekTotal
    )

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0 // Retina

    guard let cgImage = renderer.cgImage else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / 2, height: cgImage.height / 2))
}

@MainActor
func saveAndCopyShareCard(
    sessions: [AppSession],
    totalActive: TimeInterval,
    totalRunning: TimeInterval,
    sessionDuration: TimeInterval,
    bestStreak: TimeInterval,
    contextSwitches: Int,
    weekTotals: [TimeInterval],
    previousWeekTotal: TimeInterval
) -> Bool {
    guard let image = renderShareCard(
        sessions: sessions,
        totalActive: totalActive,
        totalRunning: totalRunning,
        sessionDuration: sessionDuration,
        bestStreak: bestStreak,
        contextSwitches: contextSwitches,
        weekTotals: weekTotals,
        previousWeekTotal: previousWeekTotal
    ) else { return false }

    // Copy to clipboard
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])

    // Save to Desktop
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMd"
    let filename = "vibetime-\(formatter.string(from: Date())).png"
    let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    let fileURL = desktopURL.appendingPathComponent(filename)

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else { return false }

    try? pngData.write(to: fileURL, options: .atomic)

    return true
}
