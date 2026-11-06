import Foundation

/// Publisher details shown in the app and used for App Store / TestFlight.
enum AppInfo {
    static let publisher = "NetTek Ltd"
    static let copyright = "© 2026 NetTek Ltd"
    static let website = URL(string: "https://nettek.uk")!
    static let supportURL = URL(string: "https://nettek.uk/indoor-softball/")!
    static let privacyURL = URL(string: "https://nettek.uk/indoor-softball/privacy/")!
    static let supportEmail = "support@nettek.uk"

    static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
