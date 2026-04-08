import SwiftUI

struct LogsView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedLevel: LogLevel? = nil
    @State private var autoScroll = true

    var filteredLogs: [LogEntry] {
        if let level = selectedLevel {
            return vpnManager.logs.filter { $0.level == level }
        }
        return vpnManager.logs
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.top, 60)

            filterBar
                .padding(.top, 12)
                .padding(.horizontal, 20)

            if filteredLogs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Логи")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 12) {
                Text("\(vpnManager.logs.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#8A9BB8"))
                Button {
                    withAnimation { vpnManager.clearLogs() }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FC5C7D"))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "Все")
                filterChip(.info, label: "Info")
                filterChip(.warning, label: "Warn")
                filterChip(.error, label: "Error")
                filterChip(.debug, label: "Debug")
            }
        }
    }

    private func filterChip(_ level: LogLevel?, label: String) -> some View {
        let isSelected = selectedLevel == level
        let color: Color = level?.color ?? Color(hex: "#8A9BB8")
        return Button {
            withAnimation(.spring(response: 0.25)) { selectedLevel = level }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.3) : Color(hex: "#1A1A2E"))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? color.opacity(0.5) : Color(hex: "#2A2A3E"), lineWidth: 1))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#2A2A3E"))
            Text("Логи пусты")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#444460"))
            Spacer()
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(filteredLogs) { entry in
                        LogRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .onChange(of: vpnManager.logs.count) { _, _ in
                if autoScroll, let first = filteredLogs.first {
                    withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
    }
}

struct LogRow: View {
    let entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#444460"))
                .frame(width: 82, alignment: .leading)
                .padding(.top, 2)

            Text(entry.level.prefix)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(entry.level.color)
                .frame(width: 32, alignment: .leading)
                .padding(.top, 2)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(entry.level == .error ? Color(hex: "#FC5C7D") :
                    entry.level == .warning ? Color(hex: "#FCA85C") : Color(hex: "#8A9BB8"))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(entry.level == .error ? Color(hex: "#FC5C7D").opacity(0.05) :
            entry.level == .warning ? Color(hex: "#FCA85C").opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
