import Foundation

/// EventTape is the append-only JSONL log. File IO stays off the main thread.
actor EventTape {
    private let root: URL
    private var lines: [TapeLine] = []
    private var projection: KitchenProjection = .empty
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(root: URL) {
        self.root = root
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func current() -> KitchenProjection { projection }

    func replay() -> (KitchenProjection, String?) {
        ensureDirectory()
        var notice: String?
        if let snap = loadSnapshot(preferringBackup: false) {
            projection = snap.projection
            projection.eventCount = snap.eventCount
        } else if let snap = loadSnapshot(preferringBackup: true) {
            projection = snap.projection
            projection.eventCount = snap.eventCount
            notice = "snapshot recovered from backup"
        }

        let loaded = loadLines(preferringBackup: false) ?? loadLines(preferringBackup: true)
        if loaded == nil && FileManager.default.fileExists(atPath: eventsURL.path) {
            notice = "event tape unreadable; starting empty buffer"
            projection = .empty
            lines = []
            return (projection, notice)
        }
        if let loaded {
            lines = loaded
            if projection.eventCount > 0 && projection.eventCount <= loaded.count {
                let tail = loaded.suffix(from: projection.eventCount)
                for line in tail {
                    projection = KitchenFold.apply(line.body, onto: projection)
                }
            } else {
                var rebuilt = KitchenProjection.empty
                for line in loaded {
                    rebuilt = KitchenFold.apply(line.body, onto: rebuilt)
                }
                projection = rebuilt
            }
            projection.eventCount = loaded.count
        } else {
            lines = []
        }
        return (projection, notice)
    }

    func append(_ body: TapeBody) -> KitchenProjection {
        let line = TapeLine(schemaVersion: 1, occurredAt: Date(), body: body)
        lines.append(line)
        projection = KitchenFold.apply(body, onto: projection)
        projection.eventCount = lines.count
        persistEvents()
        if lines.count > 0 && lines.count.isMultiple(of: 200) {
            persistSnapshot()
        }
        return projection
    }

    func flushBuffer() {
        persistEvents()
        persistSnapshot()
    }

    func resetAllData() -> KitchenProjection {
        lines = []
        projection = KitchenFold.apply(.storeWiped, onto: .empty)
        persistEvents()
        persistSnapshot()
        return projection
    }

    private var eventsURL: URL { root.appendingPathComponent("events.jsonl") }
    private var snapshotURL: URL { root.appendingPathComponent("snapshot.json") }

    private func ensureDirectory() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            // Directory create failed; writes will no-op and memory stays authoritative.
        }
    }

    private func persistEvents() {
        ensureDirectory()
        backupIfNeeded(eventsURL)
        var data = Data()
        for line in lines {
            do {
                let encoded = try encoder.encode(line)
                data.append(encoded)
                data.append(0x0A)
            } catch {
                // Skip a line that cannot encode; memory remains the source of truth.
            }
        }
        writeAtomic(data, to: eventsURL)
    }

    private func persistSnapshot() {
        ensureDirectory()
        backupIfNeeded(snapshotURL)
        let snap = TapeSnapshot(schemaVersion: 1, eventCount: lines.count, projection: projection)
        do {
            let data = try encoder.encode(snap)
            writeAtomic(data, to: snapshotURL)
        } catch {
            // Snapshot is optional; replay can rebuild from the tape.
        }
    }

    private func writeAtomic(_ data: Data, to url: URL) {
        let tmp = root.appendingPathComponent(".\(url.lastPathComponent).tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    private func backupIfNeeded(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.appendingPathExtension("backup")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: url, to: backup)
    }

    private func loadLines(preferringBackup: Bool) -> [TapeLine]? {
        let url = preferringBackup ? eventsURL.appendingPathExtension("backup") : eventsURL
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return preferringBackup ? nil : [] }
        var parsed: [TapeLine] = []
        let chunks = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        for chunk in chunks {
            do {
                let line = try decoder.decode(TapeLine.self, from: Data(chunk))
                if line.schemaVersion == 1 {
                    parsed.append(line)
                }
            } catch {
                // Skip a corrupt line and keep replaying the rest.
            }
        }
        return parsed
    }

    private func loadSnapshot(preferringBackup: Bool) -> TapeSnapshot? {
        let url = preferringBackup ? snapshotURL.appendingPathExtension("backup") : snapshotURL
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let snap = try decoder.decode(TapeSnapshot.self, from: data)
            return snap.schemaVersion == 1 ? snap : nil
        } catch {
            return nil
        }
    }
}
