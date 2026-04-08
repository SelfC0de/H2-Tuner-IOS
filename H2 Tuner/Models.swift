import SwiftUI
import Foundation

enum AppTab: String, CaseIterable {
    case home = "house.fill"
    case servers = "server.rack"
    case logs = "doc.text.fill"
    case settings = "gearshape.fill"

    var label: String {
        switch self {
        case .home: return "Главная"
        case .servers: return "Серверы"
        case .logs: return "Логи"
        case .settings: return "Настройки"
        }
    }
}

enum VPNProtocol: String, CaseIterable, Codable {
    case vless = "vless"
    case vmess = "vmess"
    case trojan = "trojan"
    case shadowsocks = "ss"
    case hysteria2 = "hysteria2"

    var displayName: String {
        switch self {
        case .vless: return "VLESS"
        case .vmess: return "VMess"
        case .trojan: return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .hysteria2: return "Hysteria2"
        }
    }

    var accentColor: Color {
        switch self {
        case .vless: return Color(hex: "#7C5CFC")
        case .vmess: return Color(hex: "#5CF0FC")
        case .trojan: return Color(hex: "#FC5C7D")
        case .shadowsocks: return Color(hex: "#FCA85C")
        case .hysteria2: return Color(hex: "#5CFC8A")
        }
    }

    var icon: String {
        switch self {
        case .vless: return "bolt.shield.fill"
        case .vmess: return "shield.lefthalf.filled"
        case .trojan: return "theatermasks.fill"
        case .shadowsocks: return "eye.slash.fill"
        case .hysteria2: return "hare.fill"
        }
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var label: String {
        switch self {
        case .disconnected: return "Отключено"
        case .connecting: return "Подключение..."
        case .connected: return "Подключено"
        case .disconnecting: return "Отключение..."
        case .error(let msg): return "Ошибка: \(msg)"
        }
    }

    var color: Color {
        switch self {
        case .disconnected: return Color(hex: "#666680")
        case .connecting: return Color(hex: "#FCA85C")
        case .connected: return Color(hex: "#5CFC8A")
        case .disconnecting: return Color(hex: "#FCA85C")
        case .error: return Color(hex: "#FC5C7D")
        }
    }
}

struct ServerConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var link: String
    var `protocol`: VPNProtocol
    var host: String
    var port: Int
    var uuid: String?
    var password: String?
    var method: String?
    var network: String?
    var path: String?
    var tls: Bool
    var sni: String?
    var flow: String?
    var fp: String?
    var pbk: String?
    var sid: String?
    var remarks: String?
    var addedAt: Date = Date()

    static func == (lhs: ServerConfig, rhs: ServerConfig) -> Bool {
        lhs.id == rhs.id
    }
}

struct IPInfo: Equatable {
    var ip: String
    var country: String?
    var city: String?
    var org: String?
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: ToastStyle
}

enum ToastStyle {
    case success, error, info, warning

    var color: Color {
        switch self {
        case .success: return Color(hex: "#5CFC8A")
        case .error: return Color(hex: "#FC5C7D")
        case .info: return Color(hex: "#5CF0FC")
        case .warning: return Color(hex: "#FCA85C")
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
