import SwiftData
import SwiftUI

@main
struct PreSlabApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(
            for: AssessmentRecord.self,
            inMemory: ProcessInfo.processInfo.arguments.contains("--uitesting")
        )
    }
}
