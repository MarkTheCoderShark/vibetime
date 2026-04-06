import Foundation

class Storage {
    private let fileManager = FileManager.default
    private let dataDirectory: URL

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dataDirectory = appSupport.appendingPathComponent("vibetime", isDirectory: true)

        if !fileManager.fileExists(atPath: dataDirectory.path) {
            try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        }
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func fileURL(for dateKey: String) -> URL {
        dataDirectory.appendingPathComponent("\(dateKey).json")
    }

    func saveDay(_ record: DayRecord) {
        let url = fileURL(for: record.date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(record) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadDay(for dateKey: String) -> DayRecord? {
        let url = fileURL(for: dateKey)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DayRecord.self, from: data)
    }

    func loadToday() -> DayRecord? {
        loadDay(for: Storage.todayKey())
    }

    func loadWeek() -> [DayRecord] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        var records: [DayRecord] = []
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let key = formatter.string(from: date)
            if let record = loadDay(for: key) {
                records.append(record)
            } else {
                // Empty record for days with no data
                records.append(DayRecord(date: key, sessions: [:], totalContextSwitches: 0, sessionStartTime: nil))
            }
        }
        return records
    }

    func loadDays(from startKey: String, to endKey: String) -> [DayRecord] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        guard let startDate = formatter.date(from: startKey),
              let endDate = formatter.date(from: endKey) else { return [] }

        var records: [DayRecord] = []
        var current = startDate
        while current <= endDate {
            let key = formatter.string(from: current)
            if let record = loadDay(for: key) {
                records.append(record)
            } else {
                records.append(DayRecord(date: key, sessions: [:], totalContextSwitches: 0, sessionStartTime: nil))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return records
    }

    func pruneOldData(keepDays: Int = 30) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: Date()) else { return }

        guard let files = try? fileManager.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil) else { return }

        for file in files where file.pathExtension == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            if let fileDate = formatter.date(from: name), fileDate < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
