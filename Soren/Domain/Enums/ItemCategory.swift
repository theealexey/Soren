import Foundation

/// High-level category for grouping and filtering recurring items.
/// UI-specific properties (icon, color) live in Core/DesignSystem/Extensions/ItemCategory+UI.swift.
enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case video
    case music
    case books
    case cloud
    case productivity
    case aiTools
    case shopping
    case banking
    case mobile
    case internet
    case health
    case games
    case vpn
    case food
    case education
    case creators
    case other
    case dating
}
