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
        AchievementRecord.self
    ])

    /// Production container: local store + CloudKit private database sync.
    static func makeContainer() -> ModelContainer {
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
