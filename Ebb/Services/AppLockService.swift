import Foundation
import LocalAuthentication

/// Optional Face ID / passcode lock for the app.
@MainActor
final class AppLockService: ObservableObject {
    @Published private(set) var isLocked = false

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var canUseLock: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lock() {
        isLocked = true
    }

    /// Asks for Face ID / Touch ID / passcode. Returns true if unlocked.
    @discardableResult
    func unlock() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Ebb to see your health notes.")
            if success { isLocked = false }
            return success
        } catch {
            return false
        }
    }

    /// Used when turning the lock on, to confirm it works.
    func verify() async -> Bool {
        let context = LAContext()
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Confirm to turn on the app lock.")) ?? false
    }

    func disable() {
        isLocked = false
    }
}
