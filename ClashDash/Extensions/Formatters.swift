import Foundation

extension Int64 {
    func formattedBytes() -> String {
        let absValue = Swift.abs(self)
        switch absValue {
        case 0..<1024:
            return "\(self) B"
        case 1024..<1_048_576:
            return String(format: "%.1f KB", Double(self) / 1024.0)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1f MB", Double(self) / 1_048_576.0)
        default:
            return String(format: "%.2f GB", Double(self) / 1_073_741_824.0)
        }
    }

    func formattedSpeed() -> String {
        let sign = self < 0 ? "-" : ""
        let absValue = Swift.abs(self)
        switch absValue {
        case 0..<1024:
            return "\(sign)\(absValue) B/s"
        case 1024..<1_048_576:
            return String(format: "\(sign)%.1f KB/s", Double(absValue) / 1024.0)
        case 1_048_576..<1_073_741_824:
            return String(format: "\(sign)%.1f MB/s", Double(absValue) / 1_048_576.0)
        default:
            return String(format: "\(sign)%.2f GB/s", Double(absValue) / 1_073_741_824.0)
        }
    }
}

extension Int {
    func formattedDelay() -> String {
        if self <= 0 { return "Timeout" }
        return "\(self)ms"
    }
}
