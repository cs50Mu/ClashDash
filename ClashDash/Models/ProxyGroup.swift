import Foundation

enum ProxyGroupType: String, Codable {
    case selector = "Selector"
    case urlTest = "URLTest"
    case fallback = "Fallback"
    case loadBalance = "LoadBalance"
    case relay = "Relay"

    var iconName: String {
        switch self {
        case .selector: "list.bullet"
        case .urlTest: "bolt"
        case .fallback: "arrow.triangle.swap"
        case .loadBalance: "arrow.left.arrow.right"
        case .relay: "arrow.triangle.branch"
        }
    }

    var displayName: String {
        switch self {
        case .selector: "手动选择"
        case .urlTest: "自动测速"
        case .fallback: "故障转移"
        case .loadBalance: "负载均衡"
        case .relay: "链式代理"
        }
    }
}

struct ProxyGroup: Codable, Identifiable {
    let name: String
    let type: ProxyGroupType
    let now: String?
    let all: [String]?
    let hidden: Bool
    var delay: Int?

    var id: String { name }

    var currentNodeName: String { now ?? "-" }

    var isSwitching: Bool { type == .selector }

    private enum CodingKeys: String, CodingKey {
        case name, type, now, all, hidden
    }
}
