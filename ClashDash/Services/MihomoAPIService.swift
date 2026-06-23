import Foundation

enum MihomoAPIError: LocalizedError {
    case invalidURL
    case requestFailed(Int, String)
    case decodingFailed(String)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: "无效的服务器地址"
        case .requestFailed(let code, let msg): "请求失败 (\(code)): \(msg)"
        case .decodingFailed(let msg): "数据解析失败: \(msg)"
        case .networkError(let err): "网络错误: \(err.localizedDescription)"
        case .timeout: "连接超时"
        }
    }
}

final class MihomoAPIService {
    private let config: ServerConfig
    private let secret: String
    private let session: URLSession

    private var baseURL: URL { config.baseURL }

    init(config: ServerConfig, secret: String) {
        self.config = config
        self.secret = secret

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Request builder

    private func request(path: String, method: String = "GET", body: Data? = nil, query: [URLQueryItem]? = nil) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if let query, !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else { throw MihomoAPIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let err as URLError where err.code == .timedOut {
            throw MihomoAPIError.timeout
        } catch {
            throw MihomoAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MihomoAPIError.requestFailed(0, "No HTTP response")
        }

        if httpResponse.statusCode == 204 {
            // No content, return empty success
            guard let empty = EmptyResponse() as? T else {
                throw MihomoAPIError.decodingFailed("Expected no content but got typed request")
            }
            return empty
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            DebugLog.shared.log("HTTP \(httpResponse.statusCode) \(request.url?.path ?? "?") → \(errorMsg)")
            throw MihomoAPIError.requestFailed(httpResponse.statusCode, errorMsg)
        }

        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            DebugLog.shared.log("OK \(request.url?.path ?? "?") (\(data.count)B)")
            return result
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<not utf8>"
            DebugLog.shared.log("DECODE \(request.url?.path ?? "?"): \(error.localizedDescription)")
            DebugLog.shared.log("BODY: \(body.prefix(300))")
            throw MihomoAPIError.decodingFailed("\(error.localizedDescription)\nBody: \(body.prefix(500))")
        }
    }

    private func performNoContent(_ request: URLRequest) async throws {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let err as URLError where err.code == .timedOut {
            throw MihomoAPIError.timeout
        } catch {
            throw MihomoAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MihomoAPIError.requestFailed(0, "No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw MihomoAPIError.requestFailed(httpResponse.statusCode, errorMsg)
        }
    }

    // MARK: - Version

    func fetchVersion() async throws -> VersionInfo {
        let req = try request(path: "version")
        return try await perform(req)
    }

    // MARK: - Traffic & Memory

    func fetchTraffic() async throws -> TrafficInfo {
        let req = try request(path: "traffic")
        return try await perform(req)
    }

    func fetchMemory() async throws -> MemoryInfo {
        let req = try request(path: "memory")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw MihomoAPIError.networkError(error) }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw MihomoAPIError.requestFailed(0, "Failed to fetch memory")
        }

        DebugLog.shared.log("OK /memory (\(data.count)B)")

        // Try object format first: {"inuse": 12345, "oslimit": 67890}
        if let mem = try? JSONDecoder().decode(MemoryInfo.self, from: data) {
            return mem
        }
        // Try plain number format
        if let rawValue = try? JSONDecoder().decode(Int64.self, from: data) {
            return MemoryInfo(inuse: rawValue, oslimit: nil)
        }
        throw MihomoAPIError.decodingFailed("Unknown memory response format")
    }

    // MARK: - Proxies

    func fetchProxies() async throws -> (groups: [ProxyGroup], nodes: [ProxyNode], providers: [ProxyProvider]) {
        let req = try request(path: "proxies")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw MihomoAPIError.networkError(error) }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw MihomoAPIError.requestFailed(0, "Failed to fetch proxies")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let proxiesDict = json["proxies"] as? [String: [String: Any]] else {
            throw MihomoAPIError.decodingFailed("Invalid proxies response")
        }

        var groups: [ProxyGroup] = []
        var nodes: [ProxyNode] = []
        let providers: [ProxyProvider] = []

        for (name, dict) in proxiesDict {
            guard let typeStr = dict["type"] as? String else { continue }

            if let groupType = ProxyGroupType(rawValue: typeStr) {
                let group = ProxyGroup(
                    name: name,
                    type: groupType,
                    now: dict["now"] as? String,
                    all: dict["all"] as? [String],
                    delay: nil
                )
                groups.append(group)
            } else {
                let node = ProxyNode(name: name, type: typeStr, delay: nil)
                nodes.append(node)
            }
        }

        return (groups, nodes, providers)
    }

    func switchProxy(groupName: String, to proxyName: String) async throws {
        let body = try JSONEncoder().encode(["name": proxyName])
        let req = try request(path: "proxies/\(groupName)", method: "PUT", body: body)
        try await performNoContent(req)
    }

    func testDelay(proxyName: String, url: String, timeout: Int) async throws -> Int {
        let query = [URLQueryItem(name: "url", value: url), URLQueryItem(name: "timeout", value: "\(timeout)")]
        let req = try request(path: "proxies/\(proxyName)/delay", query: query)
        let response: ProxyDelayResponse = try await perform(req)
        return response.delay
    }

    func clearFixedProxy(groupName: String) async throws {
        let req = try request(path: "proxies/\(groupName)", method: "DELETE")
        try await performNoContent(req)
    }

    // MARK: - Proxy Providers

    func fetchProxyProviders() async throws -> [ProxyProvider] {
        let req = try request(path: "providers/proxies")
        let response: ProviderListResponse = try await perform(req)
        return response.providers.map { $0.value }
    }

    func updateProvider(name: String) async throws {
        let req = try request(path: "providers/proxies/\(name)", method: "PUT")
        try await performNoContent(req)
    }

    func healthCheckProvider(provider: String, proxy: String, url: String, timeout: Int) async throws -> Int {
        let query = [URLQueryItem(name: "url", value: url), URLQueryItem(name: "timeout", value: "\(timeout)")]
        let req = try request(path: "providers/proxies/\(provider)/\(proxy)/healthcheck", query: query)
        let response: ProxyDelayResponse = try await perform(req)
        return response.delay
    }

    // MARK: - Rules

    func fetchRules() async throws -> [RuleItem] {
        let req = try request(path: "rules")
        let response: RuleListResponse = try await perform(req)
        return response.rules
    }

    func updateRuleDisable(updates: [Int: Bool]) async throws {
        let body = try JSONEncoder().encode(updates.mapKeys { String($0) })
        let req = try request(path: "rules/disable", method: "PATCH", body: body)
        try await performNoContent(req)
    }

    // MARK: - Connections

    func fetchConnections() async throws -> ConnectionsResponse {
        let req = try request(path: "connections")
        return try await perform(req)
    }

    func closeAllConnections() async throws {
        let req = try request(path: "connections", method: "DELETE")
        try await performNoContent(req)
    }

    func closeConnection(id: String) async throws {
        let req = try request(path: "connections/\(id)", method: "DELETE")
        try await performNoContent(req)
    }

    // MARK: - Config & System

    func fetchConfigs() async throws -> [String: Any] {
        let req = try request(path: "configs")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw MihomoAPIError.networkError(error) }
        guard (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0) else {
            throw MihomoAPIError.requestFailed(0, "Failed to fetch configs")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json
    }

    func reloadConfig() async throws {
        let req = try request(path: "configs", method: "PUT", query: [URLQueryItem(name: "force", value: "true")])
        try await performNoContent(req)
    }

    func restartKernel() async throws {
        let req = try request(path: "restart", method: "POST", body: "{}".data(using: .utf8))
        try await performNoContent(req)
    }

    func flushFakeIPCache() async throws {
        let req = try request(path: "cache/fakeip/flush", method: "POST")
        try await performNoContent(req)
    }
}

// MARK: - Internal types

private struct EmptyResponse: Codable {}

private struct ProviderListResponse: Codable {
    let providers: [String: ProxyProvider]
}

extension Dictionary where Key == Int {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
