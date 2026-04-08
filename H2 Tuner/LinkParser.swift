import Foundation

struct LinkParser {

    static func parse(_ link: String) throws -> ServerConfig {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if      trimmed.hasPrefix("vless://")     { return try parseVLESS(trimmed) }
        else if trimmed.hasPrefix("vmess://")     { return try parseVMess(trimmed) }
        else if trimmed.hasPrefix("trojan://")    { return try parseTrojan(trimmed) }
        else if trimmed.hasPrefix("ss://")        { return try parseShadowsocks(trimmed) }
        else if trimmed.hasPrefix("hysteria2://") || trimmed.hasPrefix("hy2://") {
            return try parseHysteria2(trimmed)
        }
        throw ParseError.unsupportedProtocol
    }

    // MARK: VLESS
    private static func parseVLESS(_ link: String) throws -> ServerConfig {
        guard let components = URLComponents(string: link) else { throw ParseError.invalidFormat }
        let uuid    = components.user ?? ""
        let host    = components.host ?? ""
        let port    = components.port ?? 443
        let remarks = components.fragment?.removingPercentEncoding ?? host
        let params  = queryParams(components)

        let security = params["security"] ?? "none"
        let tls      = security == "tls" || security == "reality"
        let network  = params["type"] ?? params["network"] ?? "tcp"

        return ServerConfig(
            name: remarks, link: link, protocol: .vless,
            host: host, port: port, uuid: uuid,
            network: network, path: params["path"],
            tls: tls, sni: params["sni"] ?? params["serverName"],
            flow: params["flow"], fp: params["fp"],
            pbk: params["pbk"], sid: params["sid"]
        )
    }

    // MARK: VMess
    private static func parseVMess(_ link: String) throws -> ServerConfig {
        let b64 = String(link.dropFirst("vmess://".count))
        guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
                      ?? Data(base64Encoded: padBase64(b64)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.base64DecodeFailed
        }

        let host    = json["add"] as? String ?? ""
        let port    = intVal(json["port"]) ?? 443
        let uuid    = json["id"] as? String ?? ""
        let remarks = json["ps"] as? String ?? host
        let tls     = (json["tls"] as? String ?? "") == "tls"
        let network = json["net"] as? String ?? "tcp"
        let path    = json["path"] as? String
        let sni     = json["sni"] as? String ?? json["host"] as? String
        let fp      = json["fp"] as? String

        return ServerConfig(
            name: remarks, link: link, protocol: .vmess,
            host: host, port: port, uuid: uuid,
            network: network, path: path,
            tls: tls, sni: sni, fp: fp
        )
    }

    // MARK: Trojan
    private static func parseTrojan(_ link: String) throws -> ServerConfig {
        guard let components = URLComponents(string: link) else { throw ParseError.invalidFormat }
        let password = components.user ?? ""
        let host     = components.host ?? ""
        let port     = components.port ?? 443
        let remarks  = components.fragment?.removingPercentEncoding ?? host
        let params   = queryParams(components)
        let network  = params["type"] ?? params["network"] ?? "tcp"

        return ServerConfig(
            name: remarks, link: link, protocol: .trojan,
            host: host, port: port, password: password,
            network: network, path: params["path"],
            tls: true,
            sni: params["sni"] ?? params["serverName"],
            fp: params["fp"]
        )
    }

    // MARK: Shadowsocks
    private static func parseShadowsocks(_ link: String) throws -> ServerConfig {
        var raw = String(link.dropFirst("ss://".count))

        var fragment: String? = nil
        if let hashIdx = raw.firstIndex(of: "#") {
            fragment = String(raw[raw.index(after: hashIdx)...]).removingPercentEncoding
            raw = String(raw[..<hashIdx])
        }

        let method: String
        let password: String
        let host: String
        let port: Int

        if let atIdx = raw.lastIndex(of: "@") {
            let cred   = String(raw[..<atIdx])
            let server = String(raw[raw.index(after: atIdx)...])

            let decoded: String
            if let d = Data(base64Encoded: cred, options: .ignoreUnknownCharacters) ?? Data(base64Encoded: padBase64(cred)),
               let s = String(data: d, encoding: .utf8) { decoded = s } else { decoded = cred }

            let colonIdx = decoded.firstIndex(of: ":") ?? decoded.endIndex
            method   = String(decoded[..<colonIdx])
            password = colonIdx < decoded.endIndex ? String(decoded[decoded.index(after: colonIdx)...]) : ""

            let parts = server.components(separatedBy: ":")
            host = parts.dropLast().joined(separator: ":").trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            port = Int(parts.last ?? "443") ?? 443
        } else {
            throw ParseError.invalidFormat
        }

        return ServerConfig(
            name: fragment ?? host, link: link, protocol: .shadowsocks,
            host: host, port: port, password: password, method: method,
            tls: false
        )
    }

    // MARK: Hysteria2
    private static func parseHysteria2(_ link: String) throws -> ServerConfig {
        let normalised = link.hasPrefix("hy2://")
            ? "hysteria2://" + link.dropFirst("hy2://".count) : link
        guard let components = URLComponents(string: normalised) else { throw ParseError.invalidFormat }
        let password = components.user ?? ""
        let host     = components.host ?? ""
        let port     = components.port ?? 443
        let remarks  = components.fragment?.removingPercentEncoding ?? host
        let params   = queryParams(components)

        return ServerConfig(
            name: remarks, link: link, protocol: .hysteria2,
            host: host, port: port, password: password,
            tls: true, sni: params["sni"]
        )
    }

    // MARK: Helpers
    private static func queryParams(_ c: URLComponents) -> [String: String] {
        var d: [String: String] = [:]
        for item in c.queryItems ?? [] {
            if let v = item.value { d[item.name] = v }
        }
        return d
    }

    private static func padBase64(_ s: String) -> String {
        let r = s.count % 4
        return r == 0 ? s : s + String(repeating: "=", count: 4 - r)
    }

    private static func intVal(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let s = v as? String { return Int(s) }
        return nil
    }
}

enum ParseError: LocalizedError {
    case unsupportedProtocol, invalidFormat, base64DecodeFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedProtocol: return "Неподдерживаемый протокол"
        case .invalidFormat:       return "Неверный формат ссылки"
        case .base64DecodeFailed:  return "Ошибка декодирования Base64"
        }
    }
}
