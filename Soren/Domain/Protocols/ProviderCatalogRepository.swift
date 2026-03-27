import Foundation

protocol ProviderCatalogRepository: Sendable {
    func fetchAll() async -> [ProviderTemplate]
    func fetchByRegion(_ region: ProviderTemplate.Region) async -> [ProviderTemplate]
    func fetchByCategory(_ category: ItemCategory) async -> [ProviderTemplate]
    func search(query: String) async -> [ProviderTemplate]
    func fetch(id: String) async -> ProviderTemplate?
}
