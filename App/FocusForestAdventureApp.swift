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

    @Environment(\.scenePhase) private var scenePhase

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
                .onChange(of: scenePhase) { _, phase in
                    // Pick up a voice the parent may have just downloaded in
                    // Settings → Accessibility — no app relaunch needed.
                    //
                    // Guarded: scene flaps to .active when a permission alert
                    // closes, and scanning voices while speech RECOGNITION is
                    // spinning up trips a dispatch assertion inside Apple's
                    // speech frameworks (iOS 18). Wait out the churn and skip
                    // entirely if the mic is (or becomes) live.
                    guard phase == .active else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !dependencies.voiceManager.isListening else { return }
                        dependencies.speechService.refreshVoice()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
