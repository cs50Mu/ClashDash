import Foundation

struct ProxyNode: Codable, Identifiable, Hashable {
    let name: String
    let type: String
    var delay: Int?

    var id: String { name }

    var isDirect: Bool { type == "Direct" }
    var isReject: Bool { type == "Reject" || type == "RejectDrop" }

    private enum CodingKeys: String, CodingKey {
        case name, type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: ProxyNode, rhs: ProxyNode) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type
    }
}
