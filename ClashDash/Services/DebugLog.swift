import Foundation
import OSLog

final class DebugLog {
    static let shared = DebugLog()
    private let logger = Logger(subsystem: "com.clashdash.app", category: "api")
    private var buffer: [String] = []
    private let maxBuffer = 500
    private let lock = NSLock()
    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("clashdash_debug.log")
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func log(_ message: String) {
        let timestamp = DateFormatter()
        timestamp.dateFormat = "HH:mm:ss.SSS"
        let entry = "[\(timestamp.string(from: Date()))] [CD] \(message)"

        // Send to unified log AND NSLog so both log collect and idevicesyslog can read
        logger.info("[CD] \(message, privacy: .public)")
        NSLog("%@", entry)

        lock.lock()
        buffer.append(message)
        if buffer.count > maxBuffer { buffer.removeFirst() }
        lock.unlock()

        if let data = "\(entry)\n".data(using: .utf8) {
            if let fh = try? FileHandle(forWritingTo: fileURL) {
                fh.seekToEndOfFile()
                try? fh.write(contentsOf: data)
                try? fh.close()
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    var logFilePath: String { fileURL.path }

    func allEntries() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    func clear() {
        lock.lock()
        buffer.removeAll()
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        lock.unlock()
    }
}
