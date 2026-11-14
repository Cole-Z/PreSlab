import Foundation
import SwiftData
import Testing
@testable import PreSlab

@Test @MainActor func startupOpensTheStoreOnlyOnce() async throws {
    let factory = StartupTestStore()
    let startup = AppStartup(openStore: { try await factory.open() })
    #expect(startup.container == nil)
    await startup.load()
    let first = try #require(startup.container)
    await startup.load()
    #expect(startup.container === first)
    #expect(await factory.attempts == 1)
    #expect(!startup.isLoading)
    #expect(!startup.failed)
}

@Test @MainActor func failedStartupCanRetryWithoutCreatingAnEmptyLibrary() async throws {
    let factory = StartupTestStore(failFirst: true)
    let startup = AppStartup(openStore: { try await factory.open() })
    await startup.load()
    #expect(startup.failed)
    #expect(startup.container == nil)
    #expect(!startup.isLoading)
    await startup.load()
    #expect(startup.container != nil)
    #expect(!startup.failed)
    #expect(await factory.attempts == 2)
}

@Test @MainActor func startupReopensExistingAssessments() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.store")
    let configuration = ModelConfiguration(url: url)
    let original = try ModelContainer(for: AssessmentRecord.self, configurations: configuration)
    let id = UUID()
    let finding = try JSONEncoder().encode(SideFinding.empty)
    original.mainContext.insert(AssessmentRecord(id: id, frontFileName: "front.jpg", backFileName: "back.jpg",
                                                 frontJSON: finding, backJSON: finding, isSample: false))
    try original.mainContext.save()
    let startup = AppStartup(openStore: {
        try await Task.detached {
            try ModelContainer(for: AssessmentRecord.self, configurations: ModelConfiguration(url: url))
        }.value
    })
    await startup.load()
    let reopened = try #require(startup.container)
    let saved = try reopened.mainContext.fetch(FetchDescriptor<AssessmentRecord>())
    #expect(saved.map(\.id) == [id])
}

private actor StartupTestStore {
    var attempts = 0
    let failFirst: Bool

    init(failFirst: Bool = false) { self.failFirst = failFirst }

    func open() throws -> ModelContainer {
        attempts += 1
        if failFirst && attempts == 1 { throw CocoaError(.fileReadUnknown) }
        return try ModelContainer(for: AssessmentRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
