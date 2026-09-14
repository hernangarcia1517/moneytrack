//
//  BudgetStorePersistence.swift
//  moneytrack
//
//  Codable -> JSON in the documents directory. Loaded on launch, saved on
//  mutation (debounced by BudgetStore). No SwiftData yet — the model is
//  still moving; migrate later if sync is wanted.
//

import Foundation

struct BudgetStorePersistence {
    private struct Snapshot: Codable {
        var budgets: [Budget]
        var transactions: [Transaction]
    }

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("moneytrack-store.json")
    }

    func load() -> (budgets: [Budget], transactions: [Transaction])? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let snapshot = try? JSONDecoder.moneytrack.decode(Snapshot.self, from: data) else { return nil }
        return (snapshot.budgets, snapshot.transactions)
    }

    func save(budgets: [Budget], transactions: [Transaction]) {
        let snapshot = Snapshot(budgets: budgets, transactions: transactions)
        guard let data = try? JSONEncoder.moneytrack.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONDecoder {
    static let moneytrack: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let moneytrack: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
