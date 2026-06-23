import Foundation
import Observation

@Observable
final class RulesViewModel {
    var rules: [RuleItem] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var filterType: String?

    // Track disabled status separately (mutable)
    var disabledSet: Set<Int> = []

    private let api: MihomoAPIService

    init(api: MihomoAPIService) {
        self.api = api
    }

    var availableTypes: [String] {
        let types = Set(rules.map { $0.type })
        return types.sorted()
    }

    var filteredRules: [RuleItem] {
        var result = rules

        if !searchText.isEmpty {
            result = result.filter {
                $0.payload.localizedCaseInsensitiveContains(searchText) ||
                $0.type.localizedCaseInsensitiveContains(searchText) ||
                $0.proxy.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let filter = filterType {
            result = result.filter { $0.type == filter }
        }

        return result
    }

    func isRuleDisabled(_ index: Int) -> Bool {
        disabledSet.contains(index)
    }

    @MainActor func loadRules() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await api.fetchRules()
            self.rules = result
            // Initialize disabled set from extra data
            self.disabledSet = Set(result.filter { $0.isDisabled }.map { $0.index })
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor func toggleRule(arrayIndex: Int) async {
        let rule = rules[arrayIndex]
        let apiIndex = rule.index
        let newDisabled = !disabledSet.contains(apiIndex)

        // Optimistic update
        if newDisabled {
            disabledSet.insert(apiIndex)
        } else {
            disabledSet.remove(apiIndex)
        }

        do {
            try await api.updateRuleDisable(updates: [apiIndex: newDisabled])
        } catch {
            // Revert
            if newDisabled {
                disabledSet.remove(apiIndex)
            } else {
                disabledSet.insert(apiIndex)
            }
        }
    }
}
