//
//  ItemRepository.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

protocol ItemRepository: Sendable {
    func items(_ request: PageRequest) async throws -> Page<Item>
    func search(_ term: String, page: PageRequest) async throws -> Page<Item>
    func item(id: UUID) async throws -> Item
    func create(_ draft: ItemDraft) async throws -> Item
    func update(id: UUID, draft: ItemDraft) async throws -> Item
    func delete(id: UUID) async throws
}

extension ItemRepository {

    func items() async throws -> Page<Item> {
        try await items(.first)
    }
}

// Speaks PostgREST, Supabase's table API, mounted at rest/v1/.
// One row is a filter (?id=eq.<uuid>), an array unless Accept: ...object+json.
// Writes return an empty body unless Prefer: return=representation.
nonisolated struct LiveItemRepository: ItemRepository {

    private let api: any APIClient
    private static let path = "rest/v1/items"

    init(api: any APIClient) {
        self.api = api
    }

    func items(_ request: PageRequest) async throws -> Page<Item> {
        try await api.get(Self.path, query: request.queryItems)
    }

    // TODO: PostgREST ignores `q` — returns every row until an `or=(...ilike...)` filter.
    func search(_ term: String, page: PageRequest) async throws -> Page<Item> {
        var query = page.queryItems
        query.append(URLQueryItem(name: "q", value: term))
        return try await api.get(Self.path, query: query)
    }

    func item(id: UUID) async throws -> Item {
        let endpoint = Endpoint(
            Self.path,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Accept": "application/vnd.pgrst.object+json"]
        )
        return try await api.send(endpoint)
    }

    func create(_ draft: ItemDraft) async throws -> Item {
        let endpoint = try Endpoint(
            Self.path,
            method: .post,
            headers: [
                "Prefer": "return=representation",
                "Accept": "application/vnd.pgrst.object+json"
            ],
            body: .json(draft)
        )
        return try await api.send(endpoint)
    }

    func update(id: UUID, draft: ItemDraft) async throws -> Item {
        let endpoint = try Endpoint(
            Self.path,
            method: .patch,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: [
                "Prefer": "return=representation",
                "Accept": "application/vnd.pgrst.object+json"
            ],
            body: .json(draft)
        )
        return try await api.send(endpoint)
    }

    func delete(id: UUID) async throws {
        let endpoint = Endpoint(
            Self.path,
            method: .delete,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        )
        try await api.send(endpoint)
    }
}
