import SwiftUI

/// Dependency injection container — assembled once at app launch,
/// injected into the SwiftUI environment via `.environment()`.
/// Repositories and services will be added as the app grows.
@MainActor @Observable
final class AppContainer: Sendable {
    let id = UUID()
}
