import Foundation
import SwiftUI

class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var connectionState: ConnectionState = .disconnected
    @Published var realIP: IPInfo?
    @Published var vpnIP: IPInfo?
    @Published var connectedAt: Date?
    @Published var logs: [LogEntry] = []
    @Published var bytesUp: Int64 = 0
    @Published var bytesDown: Int64 = 0

    private var xrayProcess: Process?
    private var statsTimer: Timer?
    private let localProxyPort: Int = 10808
    private let localSocksPort: Int = 10809
    private var configFilePath: String?
    private let logQueue = DispatchQueue(label: "dev.selfcode.h2tuner.logs", qos: .utility)

    private init() { fetchRealIP() }

    func connect(server: ServerConfig) {
        guard connectionState == .disconnected else { return }
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .connecting } }
        addLog("Подключение к \(server.host):\(server.port) [\(server.protocol.displayName)]", level: .info)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let config = try XrayConfigBuilder.build(server: server, settings: SettingsStore.shared)
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("xray_cfg_\(UUID().uuidString).json")
                try config.write(to: tmpURL, atomically: true, encoding: .utf8)
                self.configFilePath = tmpURL.path

                guard let xrayPath = self.resolveXrayPath() else {
                    self.handleError("xray binary не найден — добавьте xray arm64 в проект")
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: xrayPath)
                process.arguments = ["run", "-c", tmpURL.path]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                process.terminationHandler = { [weak self] p in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        if self.connectionState == .connected || self.connectionState == .connecting {
                            self.handleError("xray завершился (код \(p.terminationStatus))")
                        }
                    }
                }

                pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    guard let self else { return }
                    let data = handle.availableData
                    guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                    let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
                    self.logQueue.async {
                        let entries = lines.map { line -> LogEntry in
                            let low = line.lowercased()
                            let level: LogLevel
                            if low.contains("error") { level = .error }
                            else if low.contains("warn") { level = .warning }
                            else if low.contains("debug") { level = .debug }
                            else { level = .info }
                            return LogEntry(message: line, level: level, timestamp: Date())
                        }
                        DispatchQueue.main.async {
                            self.logs.insert(contentsOf: entries, at: 0)
                            if self.logs.count > 500 { self.logs = Array(self.logs.prefix(500)) }
                        }
                    }
                }

                try process.run()
                self.xrayProcess = process

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    if process.isRunning {
                        withAnimation(.spring()) { self.connectionState = .connected }
                        self.connectedAt = Date()
                        self.startStatsTimer()
                        self.fetchVPNIP()
                        self.addLog("Успешно подключено", level: .info)
                    } else {
                        self.handleError("Процесс xray завершился при старте")
                    }
                }

            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        DispatchQueue.main.async { withAnimation(.spring()) { self.connectionState = .disconnecting } }
        addLog("Отключение...", level: .info)
        statsTimer?.invalidate()
        statsTimer = nil
        xrayProcess?.terminationHandler = nil
        xrayProcess?.terminate()
        xrayProcess = nil
        if let path = configFilePath {
            try? FileManager.default.removeItem(atPath: path)
            configFilePath = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring()) {
                self.connectionState = .disconnected
                self.vpnIP = nil
                self.connectedAt = nil
                self.bytesUp = 0
                self.bytesDown = 0
            }
            self.addLog("Отключено", level: .info)
        }
    }

    private func resolveXrayPath() -> String? {
        let candidates = [
            Bundle.main.path(forResource: "xray", ofType: nil),
            Bundle.main.path(forAuxiliaryExecutable: "xray"),
            Bundle.main.bundlePath + "/xray"
        ]
        for path in candidates.compactMap({ $0 }) where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: path)
            return path
        }
        return nil
    }

    private func handleError(_ msg: String) {
        DispatchQueue.main.async {
            withAnimation(.spring()) { self.connectionState = .error(msg) }
            self.addLog("Ошибка: \(msg)", level: .error)
            self.xrayProcess?.terminationHandler = nil
            self.xrayProcess?.terminate()
            self.xrayProcess = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if case .error = self.connectionState {
                    withAnimation { self.connectionState = .disconnected }
                }
            }
        }
    }

    func fetchRealIP() {
        fetchIPInfo(useSocks: false) { [weak self] info in
            DispatchQueue.main.async { self?.realIP = info }
        }
    }

    private func fetchVPNIP() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.connectionState == .connected else { return }
            self.fetchIPInfo(useSocks: true) { [weak self] info in
                DispatchQueue.main.async { self?.vpnIP = info }
            }
        }
    }

    private func fetchIPInfo(useSocks: Bool, completion: @escaping (IPInfo?) -> Void) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        if useSocks {
            config.connectionProxyDictionary = [
                "SOCKSEnable": 1,
                "SOCKSProxy": "127.0.0.1",
                "SOCKSPort": localSocksPort
            ]
        }
        let session = URLSession(configuration: config)
        guard let url = URL(string: "https://ipinfo.io/json") else { completion(nil); return }
        session.dataTask(with: url) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil); return
            }
            completion(IPInfo(
                ip: json["ip"] as? String ?? "—",
                country: json["country"] as? String,
                city: json["city"] as? String,
                org: json["org"] as? String
            ))
        }.resume()
    }

    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.simulateStats()
        }
    }

    private func simulateStats() {
        bytesUp += Int64.random(in: 800...8000)
        bytesDown += Int64.random(in: 2000...30000)
    }

    func addLog(_ message: String, level: LogLevel) {
        let entry = LogEntry(message: message, level: level, timestamp: Date())
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            if self.logs.count > 500 { self.logs = Array(self.logs.prefix(500)) }
        }
    }

    func clearLogs() { logs = [] }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let level: LogLevel
    let timestamp: Date
}

enum LogLevel {
    case info, warning, error, debug

    var color: Color {
        switch self {
        case .info:    return Color(hex: "#8A9BB8")
        case .warning: return Color(hex: "#FCA85C")
        case .error:   return Color(hex: "#FC5C7D")
        case .debug:   return Color(hex: "#5CF0FC")
        }
    }

    var prefix: String {
        switch self {
        case .info:    return "INFO"
        case .warning: return "WARN"
        case .error:   return "ERR "
        case .debug:   return "DBG "
        }
    }
}

extension Int64 {
    var formattedBytes: String {
        let kb = Double(self) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(self) B"
    }
}
