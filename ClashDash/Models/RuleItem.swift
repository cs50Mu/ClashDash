import Foundation

struct RuleItem: Codable, Identifiable {
    let index: Int
    let type: String        // ProcessName, DomainSuffix, Domain, GEOIP, MATCH, etc.
    let payload: String
    let proxy: String
    let size: Int?
    let extra: RuleExtra?

    var isDisabled: Bool { extra?.disabled ?? false }

    var id: Int { index }
}

struct RuleExtra: Codable {
    let disabled: Bool?
    let hitCount: Int?
    let hitAt: String?
    let missCount: Int?
    let missAt: String?
}

struct RuleListResponse: Codable {
    let rules: [RuleItem]
}
