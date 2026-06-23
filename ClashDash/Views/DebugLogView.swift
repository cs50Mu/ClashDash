import SwiftUI

struct DebugLogView: View {
    @State private var entries: [String] = []
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .onChange(of: entries.count) { _, _ in
                    if let last = entries.last {
                        proxy.scrollTo(entries.count - 1, anchor: .bottom)
                    }
                }
            }
            .navigationTitle("调试日志")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if DebugServer.shared.isRunning {
                        Label("curl :8080", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清除") {
                        DebugLog.shared.clear()
                        entries.removeAll()
                    }
                }
            }
        }
        .onAppear {
            entries = DebugLog.shared.allEntries()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                entries = DebugLog.shared.allEntries()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
