import Foundation

/// Publisher details shown in the app and used for App Store / TestFlight.
enum AppInfo {
    static let publisher = "NetTek Ltd"
    static let copyright = "© 2026 NetTek Ltd"
    static let website = URL(string: "https://nettek.uk")!
    static let supportURL = URL(string: "https://nettek.uk/indoor-softball/")!
    static let privacyURL = URL(string: "https://nettek.uk/indoor-softball/privacy/")!
    static let supportEmail = "support@nettek.uk"

    /// mailto: link with the app version in the subject (safely encoded).
    static var feedbackMailURL: URL {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = supportEmail
        c.queryItems = [URLQueryItem(name: "subject", value: "Indoor Softball \(version)")]
        return c.url ?? URL(string: "mailto:\(supportEmail)")!
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
