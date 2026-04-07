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
    static let appVersion = "1.0.0"
    static let supportEmail = "support@ellasid.com"
}
