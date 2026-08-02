import Foundation
import UIKit

enum ApplicationSettingsOpenResult: Sendable, Equatable {
    case opened
    case failed
}

/// Isolates UIKit URL opening from SwiftUI and makes the system Settings action testable.
@MainActor
protocol ApplicationSettingsOpening: AnyObject {
    func openApplicationSettings() async -> ApplicationSettingsOpenResult
}

@MainActor
final class UIApplicationSettingsOpener: ApplicationSettingsOpening {
    func openApplicationSettings() async -> ApplicationSettingsOpenResult {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return .failed
        }
        let opened = await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { didOpen in
                continuation.resume(returning: didOpen)
            }
        }
        return opened ? .opened : .failed
    }
}
