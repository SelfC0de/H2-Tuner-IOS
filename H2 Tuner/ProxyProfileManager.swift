import Foundation
import UIKit
import SafariServices

struct ProxyProfileManager {

    static let profileID = "dev.selfcode.h2tuner.proxy"
    static let socksPort = 10809
    static let serverPort: UInt16 = 18182

    static func generateMobileconfig() -> Data {
        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.proxy.http.global</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>\(profileID).proxy</string>
            <key>PayloadUUID</key>
            <string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>
            <key>PayloadDisplayName</key>
            <string>H2 Tuner Proxy</string>
            <key>ProxiesDict</key>
            <dict>
                <key>SOCKSEnable</key>
                <integer>1</integer>
                <key>SOCKSProxy</key>
                <string>127.0.0.1</string>
                <key>SOCKSPort</key>
                <integer>\(socksPort)</integer>
                <key>ExceptionsList</key>
                <array>
                    <string>127.0.0.1</string>
                    <string>localhost</string>
                    <string>*.local</string>
                    <string>10.*</string>
                    <string>192.168.*</string>
                    <string>172.16.*</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>H2 Tuner</string>
    <key>PayloadDescription</key>
    <string>SOCKS5 прокси для H2 Tuner VPN</string>
    <key>PayloadIdentifier</key>
    <string>\(profileID)</string>
    <key>PayloadUUID</key>
    <string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadRemovalDisallowed</key>
    <false/>
</dict>
</plist>
"""
        return xml.data(using: .utf8) ?? Data()
    }

    // MARK: - Локальный HTTP сервер + открыть в Safari

    private static var serverSocket: CFSocket?
    private static var serverRunLoopSource: CFRunLoopSource?

    static func installProfile(completion: @escaping (Bool) -> Void) {
        startLocalServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Safari блокирует http:// localhost в iOS 18 — открываем через SFSafariViewController
            // который работает с локальными HTTP адресами
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first,
                  let rootVC = window.rootViewController else {
                completion(false); return
            }
            let urlStr = "http://127.0.0.1:\(serverPort)/profile.mobileconfig"
            guard let url = URL(string: urlStr) else { completion(false); return }
            let safari = SFSafariViewController(url: url)
            safari.modalPresentationStyle = .pageSheet
            rootVC.present(safari, animated: true)
            completion(true)
        }
    }

    private static func startLocalServer() {
        stopLocalServer()

        var context = CFSocketContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        serverSocket = CFSocketCreate(nil, AF_INET, SOCK_STREAM, IPPROTO_TCP,
            CFSocketCallBackType.acceptCallBack.rawValue,
            { socket, callbackType, address, data, info in
                guard callbackType == .acceptCallBack,
                      let data = data else { return }
                let nativeHandle = data.load(as: CFSocketNativeHandle.self)
                ProxyProfileManager.handleConnection(nativeHandle)
            }, &context)

        guard let sock = serverSocket else { return }

        var yes: Int32 = 1
        setsockopt(CFSocketGetNative(sock), SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = serverPort.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let addrData = withUnsafeBytes(of: &addr) { Data($0) } as CFData
        CFSocketSetAddress(sock, addrData)

        serverRunLoopSource = CFSocketCreateRunLoopSource(nil, sock, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), serverRunLoopSource, .defaultMode)
    }

    static func stopLocalServer() {
        if let src = serverRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
            serverRunLoopSource = nil
        }
        if let sock = serverSocket {
            CFSocketInvalidate(sock)
            serverSocket = nil
        }
    }

    private static func handleConnection(_ handle: CFSocketNativeHandle) {
        let profileData = generateMobileconfig()
        let response = """
HTTP/1.1 200 OK\r
Content-Type: application/x-apple-aspen-config\r
Content-Disposition: attachment; filename="H2Tuner-proxy.mobileconfig"\r
Content-Length: \(profileData.count)\r
Connection: close\r
\r

"""
        var responseData = response.data(using: .utf8)!
        responseData.append(profileData)

        responseData.withUnsafeBytes { ptr in
            _ = send(handle, ptr.baseAddress!, responseData.count, 0)
        }
        close(handle)

        // Останавливаем сервер после отдачи файла
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            stopLocalServer()
        }
    }

    // Открыть Настройки → профили для удаления
    static func openProfileSettings() {
        let urls = [
            "App-Prefs:root=General&path=ManagedConfigurationList",
            "App-Prefs:root=General",
            UIApplication.openSettingsURLString
        ]
        for urlStr in urls {
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }
}
