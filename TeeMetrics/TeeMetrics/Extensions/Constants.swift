// MARK: - App Constants
// Centralized URLs and configuration values

import Foundation

enum AppURLs {
    // swiftlint:disable force_unwrapping — these are compile-time constant valid URLs
    static let terms = URL(string: "https://johndisalle.github.io/TeeMetrics/terms")!
    static let privacy = URL(string: "https://johndisalle.github.io/TeeMetrics/privacy")!
    static let support = URL(string: "https://johndisalle.github.io/TeeMetrics/support")!
    // swiftlint:enable force_unwrapping
}

enum AppConfig {
    /// App version read from the bundle's `CFBundleShortVersionString` so
    /// the Settings → About row always reflects what xcodegen / project.yml
    /// set as `MARKETING_VERSION`. Falls back to "1.0.0" only if the
    /// Info.plist key is missing entirely (shouldn't happen in practice).
    static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()
    static let supportEmail = "support@ellasid.com"
}
