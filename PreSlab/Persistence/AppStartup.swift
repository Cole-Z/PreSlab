import Foundation
import Observation
import OSLog
import SwiftData

/// Opens the existing store after the first screen can appear. Only the
/// container crosses threads; its mainContext is used by SwiftUI on MainActor.
@MainActor
@Observable
final class AppStartup {
    private(set) var container: ModelContainer?
    private(set) var isLoading = false
    private(set) var failed = false

    private let openStore: @Sendable () async throws -> ModelContainer
    private static let logger = Logger(subsystem: "PreSlab", category: "Startup")

    init(openStore: @escaping @Sendable () async throws -> ModelContainer = { try await AppStartup.openDefaultStore() }) {
        self.openStore = openStore
    }

    func load() async {
        guard container == nil, !isLoading else { return }
        isLoading = true
        failed = false
        let start = ContinuousClock.now
        defer { isLoading = false }
        do {
            container = try await openStore()
            Self.logger.info("Assessment store opened in \(String(describing: start.duration(to: .now)), privacy: .public)")
        } catch {
            // Never replace a store that failed to open with an empty library.
            failed = true
            Self.logger.error("Assessment store failed to open: \(String(describing: error), privacy: .private)")
        }
    }

    nonisolated static func openDefaultStore() async throws -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
        return try await Task.detached(priority: .userInitiated) {
            // Keep the same default schema, configuration and store location as
            // the former scene-level .modelContainer(for:inMemory:) modifier.
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            return try ModelContainer(for: AssessmentRecord.self, configurations: configuration)
        }.value
    }
}
