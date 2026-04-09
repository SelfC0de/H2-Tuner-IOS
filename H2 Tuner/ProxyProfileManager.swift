import Foundation
import UIKit

struct ProxyProfileManager {

    static let profileID = "dev.selfcode.h2tuner.proxy"
    static let socksPort = 10809

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

    // UIDocumentInteractionController — правильный способ открыть .mobileconfig на iOS
    static var documentController: UIDocumentInteractionController?

    static func installProfile(completion: @escaping (Bool) -> Void) {
        let data = generateMobileconfig()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("H2Tuner-proxy.mobileconfig")

        do {
            try data.write(to: tmpURL, options: .atomic)
        } catch {
            completion(false)
            return
        }

        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first,
                  let rootVC = window.rootViewController else {
                completion(false)
                return
            }

            let dc = UIDocumentInteractionController(url: tmpURL)
            dc.uti = "com.apple.mobileconfig"
            documentController = dc

            // presentOptionsMenu показывает системный диалог установки профиля
            let presented = dc.presentOptionsMenu(
                from: rootVC.view.bounds,
                in: rootVC.view,
                animated: true
            )
            completion(presented)
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
