import Foundation
import Network

final class DebugServer {
    static let shared = DebugServer()
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }
            listener?.start(queue: .global())
            isRunning = true
            DebugLog.shared.log("Debug server started on port \(port)")
        } catch {
            DebugLog.shared.log("Debug server failed: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: .global())
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            if let data, let request = String(data: data, encoding: .utf8) {
                self?.handleRequest(request, conn: conn)
            } else {
                conn.cancel()
            }
        }
    }

    private func handleRequest(_ request: String, conn: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(status: 400, body: "Bad Request", conn: conn)
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(status: 400, body: "Bad Request", conn: conn)
            return
        }

        let path = parts[1]

        if path == "/debug/logs" {
            let entries = DebugLog.shared.allEntries()
            let body = entries.joined(separator: "\n")
            sendResponse(status: 200, body: body, contentType: "text/plain; charset=utf-8", conn: conn)
        } else if path == "/debug/status" {
            let body = "ClashDash debug server running"
            sendResponse(status: 200, body: body, conn: conn)
        } else {
            sendResponse(status: 404, body: "Not Found", conn: conn)
        }
    }

    private func sendResponse(status: Int, body: String, contentType: String = "text/plain; charset=utf-8", conn: NWConnection) {
        let statusText: String = {
            switch status {
            case 200: return "OK"
            case 400: return "Bad Request"
            case 404: return "Not Found"
            default: return "Error"
            }
        }()

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }
}
