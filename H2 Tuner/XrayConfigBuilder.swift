import Foundation

struct XrayConfigBuilder {

    static func build(server: ServerConfig, settings: SettingsStore) throws -> String {
        let inbounds: [[String: Any]] = [
            [
                "tag": "http-in", "port": 10808, "listen": "127.0.0.1", "protocol": "http",
                "settings": ["allowTransparent": false],
                "sniffing": ["enabled": settings.sniffEnabled, "destOverride": ["http","tls","quic"]]
            ],
            [
                "tag": "socks-in", "port": 10809, "listen": "127.0.0.1", "protocol": "socks",
                "settings": ["auth": "noauth", "udp": true],
                "sniffing": ["enabled": settings.sniffEnabled, "destOverride": ["http","tls","quic"]]
            ]
        ]

        var outbounds: [[String: Any]] = [try buildOutbound(server: server, settings: settings)]
        outbounds += [
            ["tag": "direct", "protocol": "freedom", "settings": [:]],
            ["tag": "block",  "protocol": "blackhole", "settings": ["response": ["type": "http"]]]
        ]

        let routing = buildRouting(settings: settings)
        let dns     = buildDNS(settings: settings)

        let config: [String: Any] = [
            "log": ["loglevel": settings.logLevel, "access": "", "error": ""],
            "dns": dns,
            "inbounds": inbounds,
            "outbounds": outbounds,
            "routing": routing
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "XrayConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON encoding failed"])
        }
        return str
    }

    // MARK: - Routing

    private static func buildRouting(settings: SettingsStore) -> [String: Any] {
        var rules: [[String: Any]] = []

        switch settings.routingMode {

        case .direct:
            // Everything goes direct — proxy outbound won't be used
            rules.append(["type": "field", "network": "tcp,udp", "outboundTag": "direct"])

        case .global:
            // Only LAN bypass if enabled
            if settings.bypassLan {
                rules += lanRules()
            }

        case .bypassRu:
            if settings.bypassLan {
                rules += lanRules()
            }
            // RU domains go direct
            rules.append(["type": "field", "domain": ruBypassDomains, "outboundTag": "direct"])
        }

        return ["domainStrategy": "IPIfNonMatch", "rules": rules]
    }

    private static func lanRules() -> [[String: Any]] {
        [
            ["type": "field", "ip": ["geoip:private"], "outboundTag": "direct"],
            ["type": "field", "domain": ["geosite:private"], "outboundTag": "direct"]
        ]
    }

    // MARK: - DNS

    private static func buildDNS(settings: SettingsStore) -> [String: Any] {
        switch settings.dnsMode {
        case .system:
            return ["servers": ["localhost"], "queryStrategy": "UseIPv4"]
        case .auto:
            return [
                "servers": [
                    ["address": "https://1.1.1.1/dns-query", "domains": []],
                    "localhost"
                ],
                "queryStrategy": "UseIPv4"
            ]
        default:
            let primary = settings.effectiveDNS
            return [
                "servers": [["address": primary, "domains": []], "localhost"],
                "queryStrategy": "UseIPv4"
            ]
        }
    }

    // MARK: - Protocol builders

    private static func buildOutbound(server: ServerConfig, settings: SettingsStore) throws -> [String: Any] {
        switch server.protocol {
        case .vless:       return buildVLESS(server: server, settings: settings)
        case .vmess:       return buildVMess(server: server, settings: settings)
        case .trojan:      return buildTrojan(server: server, settings: settings)
        case .shadowsocks: return buildShadowsocks(server: server)
        case .hysteria2:   return buildHysteria2(server: server)
        }
    }

    private static func buildVLESS(server: ServerConfig, settings: SettingsStore) -> [String: Any] {
        var user: [String: Any] = ["id": server.uuid ?? "", "encryption": "none"]
        if let flow = server.flow, !flow.isEmpty { user["flow"] = flow }
        var out: [String: Any] = [
            "tag": "proxy", "protocol": "vless",
            "settings": ["vnext": [["address": server.host, "port": server.port, "users": [user]]]],
            "streamSettings": buildStreamSettings(server: server)
        ]
        if settings.enableMux { out["mux"] = ["enabled": true, "concurrency": 8] }
        return out
    }

    private static func buildVMess(server: ServerConfig, settings: SettingsStore) -> [String: Any] {
        let user: [String: Any] = ["id": server.uuid ?? "", "security": "auto", "alterId": 0]
        var out: [String: Any] = [
            "tag": "proxy", "protocol": "vmess",
            "settings": ["vnext": [["address": server.host, "port": server.port, "users": [user]]]],
            "streamSettings": buildStreamSettings(server: server)
        ]
        if settings.enableMux { out["mux"] = ["enabled": true, "concurrency": 8] }
        return out
    }

    private static func buildTrojan(server: ServerConfig, settings: SettingsStore) -> [String: Any] {
        var out: [String: Any] = [
            "tag": "proxy", "protocol": "trojan",
            "settings": ["servers": [["address": server.host, "port": server.port, "password": server.password ?? ""]]],
            "streamSettings": buildStreamSettings(server: server)
        ]
        if settings.enableMux { out["mux"] = ["enabled": true, "concurrency": 8] }
        return out
    }

    private static func buildShadowsocks(server: ServerConfig) -> [String: Any] {
        [
            "tag": "proxy", "protocol": "shadowsocks",
            "settings": ["servers": [["address": server.host, "port": server.port,
                "method": server.method ?? "chacha20-ietf-poly1305", "password": server.password ?? "", "uot": true]]]
        ]
    }

    private static func buildHysteria2(server: ServerConfig) -> [String: Any] {
        var tls: [String: Any] = ["enabled": true]
        if let sni = server.sni { tls["serverName"] = sni }
        return [
            "tag": "proxy", "protocol": "hysteria2",
            "settings": ["servers": [["address": server.host, "port": server.port, "password": server.password ?? "", "tls": tls]]]
        ]
    }

    // MARK: - Stream settings

    private static func buildStreamSettings(server: ServerConfig) -> [String: Any] {
        var stream: [String: Any] = [:]
        let network = server.network ?? "tcp"
        stream["network"] = network

        switch network {
        case "ws":
            var ws: [String: Any] = ["path": server.path ?? "/"]
            if let host = server.sni { ws["headers"] = ["Host": host] }
            stream["wsSettings"] = ws
        case "grpc":
            stream["grpcSettings"] = ["serviceName": server.path ?? ""]
        case "xhttp", "splithttp":
            stream["xhttpSettings"] = ["path": server.path ?? "/", "mode": "auto"]
        case "h2", "http":
            var h2: [String: Any] = ["path": server.path ?? "/"]
            if let sni = server.sni { h2["host"] = [sni] }
            stream["httpSettings"] = h2
        default: break
        }

        if server.tls {
            if let pbk = server.pbk, !pbk.isEmpty {
                var rs: [String: Any] = ["publicKey": pbk, "fingerprint": server.fp ?? "chrome"]
                if let sid = server.sid { rs["shortId"] = sid }
                if let sni = server.sni { rs["serverName"] = sni }
                stream["security"] = "reality"
                stream["realitySettings"] = rs
            } else {
                var tls: [String: Any] = ["allowInsecure": false, "alpn": ["h2", "http/1.1"]]
                if let sni = server.sni { tls["serverName"] = sni }
                if let fp  = server.fp  { tls["fingerprint"] = fp }
                stream["security"] = "tls"
                stream["tlsSettings"] = tls
            }
        } else {
            stream["security"] = "none"
        }
        return stream
    }
}
