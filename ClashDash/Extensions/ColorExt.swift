import SwiftUI

extension Color {
    static func delayColor(_ delay: Int?) -> Color {
        guard let delay = delay, delay > 0 else { return .gray }
        switch delay {
        case 0..<200: return .green
        case 200..<500: return .yellow
        case 500..<1000: return .orange
        default: return .red
        }
    }

    static let cardBackground = Color(.secondarySystemGroupedBackground)
}
