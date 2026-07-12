//
//  FocusForestAdventureApp.swift
//  Focus Forest Adventure
//
//  App entry point. Builds the SwiftData ModelContainer (CloudKit-backed),
//  constructs the dependency graph, and injects it into the environment.
//

import SwiftUI
import SwiftData
import TipKit

@main
struct FocusForestAdventureApp: App {

    /// Single composition root for the whole app. Built once, injected everywhere.
    @State private var dependencies: AppDependencies

    private let modelContainer: ModelContainer

    init() {
        let container = ModelContainerFactory.makeContainer()
        self.modelContainer = container
        self._dependencies = State(initialValue: AppDependencies(modelContainer: container))

        // TipKit — gentle, dismissible hints for parents (never shown mid-mission).
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .environment(dependencies.appState)
        }
        .modelContainer(modelContainer)
    }
}
