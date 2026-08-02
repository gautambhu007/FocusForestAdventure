//
//  ModelContainerFactory.swift
//  Focus Forest Adventure
//

import Foundation
import SwiftData

enum ModelContainerFactory {

    static let schema = Schema([
        ChildProfile.self,
        MissionRecord.self,
        ForestState.self,
        DailyGoal.self,
        SessionRecord.self,
        StoryRecord.self,
        AchievementRecord.self,
        CustomWord.self,
        PuzzleProgress.self,
        PuzzleSkillStat.self
    ])

    /// True when the app is running as an XCTest host. The test build isn't
    /// signed with the iCloud entitlement, and CloudKit mirroring doesn't
    /// fail politely without it — it takes the process down on a background
    /// queue, before any `try` we could catch. Tests get a local store.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Production container: local store + CloudKit private database sync.
    static func makeContainer() -> ModelContainer {
        guard !isRunningTests else {
            let testConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [testConfig])
            } catch {
                fatalError("Unable to create test ModelContainer: \(error)")
            }
        }

        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.focusforest.adventure")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // CloudKit unavailable (no iCloud account, simulator, etc.) —
            // degrade gracefully to a local-only store rather than crashing.
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Unable to create ModelContainer: \(error)")
            }
        }
    }

    /// In-memory container for unit tests and SwiftUI previews.
    static func makePreviewContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            Task { @MainActor in
                let child = ChildProfile(name: "Aanya", avatarEmoji: "🦊")
                child.forest = ForestState()
                container.mainContext.insert(child)
            }
            return container
        } catch {
            fatalError("Unable to create preview ModelContainer: \(error)")
        }
    }
}
