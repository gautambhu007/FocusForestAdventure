//
//  AppIntents.swift
//  Focus Forest Adventure
//
//  App Intents: Siri / Shortcuts / Spotlight entry points.
//  "Start a forest adventure", "Check the forest".
//

import AppIntents

struct StartAdventureIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Forest Adventure"
    static let description = IntentDescription("Opens Focus Forest Adventure and starts a new learning mission.")
    static let openAppWhenRun = true

    @Parameter(title: "Adventure")
    var adventure: AdventureEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Deep-link payload picked up by the app on activation.
        UserDefaults.standard.set(
            adventure?.id ?? "recommended",
            forKey: "pendingAdventureLaunch"
        )
        return .result()
    }
}

struct CheckForestIntent: AppIntent {
    static let title: LocalizedStringResource = "Check the Forest"
    static let description = IntentDescription("See how the child's magic forest is growing.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "pendingForestLaunch")
        return .result()
    }
}

/// Adventure choices exposed to Siri & Shortcuts.
struct AdventureEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Adventure"
    static let defaultQuery = AdventureQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AdventureQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AdventureEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AdventureEntity] {
        allEntities()
    }

    private func allEntities() -> [AdventureEntity] {
        AdventureKind.allCases.map {
            AdventureEntity(id: $0.rawValue, name: $0.localizedTitle)
        }
    }
}

struct FocusForestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartAdventureIntent(),
            phrases: [
                "Start an adventure in \(.applicationName)",
                "Play \(.applicationName)"
            ],
            shortTitle: "Start Adventure",
            systemImageName: "map.fill"
        )
        AppShortcut(
            intent: CheckForestIntent(),
            phrases: ["Check the forest in \(.applicationName)"],
            shortTitle: "Check Forest",
            systemImageName: "tree.fill"
        )
    }
}
