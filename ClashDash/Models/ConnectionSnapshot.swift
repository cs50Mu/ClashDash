import Foundation

struct ConnectionSnapshot {
    var activeConnections: [ConnectionInfo]
    var closedConnections: [ConnectionInfo]
    var uploadTotal: Int64
    var downloadTotal: Int64
    var memory: Int64?

    var activeCount: Int { activeConnections.count }
    var totalUpload: Int64 { uploadTotal }
    var totalDownload: Int64 { downloadTotal }
}
