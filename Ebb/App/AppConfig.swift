import Foundation

/// Values to fill in before launch. See docs/LAUNCH_CHECKLIST.md.
enum AppConfig {
    /// Public URL of your privacy policy (docs/PRIVACY_POLICY.md, hosted e.g. on GitHub Pages).
    static let privacyPolicyURL = URL(string: "https://example.com/ebb/privacy")!
    /// Public URL of your terms of use (docs/TERMS.md). Apple's standard EULA is also acceptable.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Support email shown in Settings.
    static let supportEmail = "support@example.com"
}
