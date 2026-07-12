//
//  BunnyAssistantViewModel.swift
//  Focus Forest Adventure
//
//  Phase 2.2: conversation state for the Bunny assistant.
//
//  Persistence policy: conversations are SESSION-ONLY and in-memory. A child's
//  chats with Bunny are never written to disk — that's the simplest possible
//  "avoid storing sensitive personal data" guarantee (see the plan's 2.2
//  acceptance criteria). History resets when the app terminates.
//

import Foundation
import Observation
import os

// MARK: - Conversation history (in-memory, capped)

struct ConversationTurn: Identifiable, Equatable, Sendable {
    enum Speaker: Equatable, Sendable { case child, bunny }
    let id = UUID()
    let speaker: Speaker
    let text: String
    let date = Date()
}

/// Session-only transcript. Capped so a long play session can't grow memory
/// unbounded; older turns simply scroll away, like a real conversation.
@Observable
@MainActor
final class ConversationHistory {
    private(set) var turns: [ConversationTurn] = []
    let maxTurns: Int

    init(maxTurns: Int = 50) {
        self.maxTurns = maxTurns
    }

    func append(_ turn: ConversationTurn) {
        turns.append(turn)
        if turns.count > maxTurns {
            turns.removeFirst(turns.count - maxTurns)
        }
    }

    func clear() {
        turns.removeAll()
    }
}

// MARK: - View model

@Observable
@MainActor
final class BunnyAssistantViewModel {

    private static let log = Logger(subsystem: "com.focusforest.adventure", category: "assistant")

    let dependencies: AppDependencies

    private(set) var isThinking = false
    var history: ConversationHistory { dependencies.conversationHistory }
    var voice: any VoiceManagerProtocol { dependencies.voiceManager }

    /// Tap-to-ask starters — the offline fallback path that always works,
    /// and the whole interaction model when voice isn't available.
    let suggestions: [String] = [
        String(localized: "Hi Bunny!"),
        String(localized: "What should I play?"),
        String(localized: "Tell me about my forest"),
        String(localized: "Tell me a joke")
    ]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        Self.log.info("🥕 assistant onAppear (turns=\(self.history.turns.count))")
        // Voice hand-off: whenever listening ends (tap, silence, or the
        // recognizer finishing), the final transcript goes straight to Bunny.
        voice.onListeningFinished = { [weak self] heard in
            guard let self else { return }
            Self.log.info("🥕 listening finished, heard \(heard.count) chars")
            let trimmed = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            Task { await self.ask(trimmed) }
        }
        guard history.turns.isEmpty else { return }
        let greeting = dependencies.conversationEngine.respond(
            to: .greeting, context: makeContext()
        )
        Self.log.info("🥕 assistant greeting generated, speaking…")
        history.append(ConversationTurn(speaker: .bunny, text: greeting))
        await dependencies.speechService.speak(greeting)
        Self.log.info("🥕 assistant greeting spoken")
    }

    /// Handles a child utterance from chips or voice.
    func ask(_ utterance: String) async {
        let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        history.append(ConversationTurn(speaker: .child, text: trimmed))
        isThinking = true
        dependencies.hapticsService.playGentleTap()

        // A short beat so Bunny visibly "thinks" — instant replies feel robotic.
        try? await Task.sleep(for: .seconds(0.6))

        let intent = dependencies.intentDetector.detect(from: trimmed)
        Self.log.info("🥕 ask: intent=\(intent.rawValue), generating reply…")
        let reply = dependencies.conversationEngine.respond(to: intent, context: makeContext())
        history.append(ConversationTurn(speaker: .bunny, text: reply))
        isThinking = false
        Self.log.info("🥕 ask: speaking reply…")
        await dependencies.speechService.speak(reply)
        Self.log.info("🥕 ask: done")
    }

    // MARK: Voice input (explicit tap, on-device only)

    func micTapped() async {
        Self.log.info("🥕 micTapped (isListening=\(self.voice.isListening))")
        if voice.isListening {
            finishListening()
            return
        }
        dependencies.speechService.stop()   // don't listen while Bunny talks
        guard await voice.requestPermission() else {
            Self.log.info("🥕 micTapped: permission denied")
            return
        }
        // The synthesizer stops on its own background queue; give it a beat
        // before flipping the audio session to record mode, or its audio
        // unit renders zero-size buffers mid-switch.
        try? await Task.sleep(for: .seconds(0.25))
        do {
            try voice.startListening()
        } catch {
            Self.log.error("🥕 micTapped: startListening threw: \(error)")
        }
        Self.log.info("🥕 micTapped: done")
    }

    private func finishListening() {
        // onListeningFinished delivers the transcript to ask().
        voice.stopListening()
    }

    // MARK: Context

    private func makeContext() -> ConversationContext {
        var context = ConversationContext()
        if let child = try? dependencies.childRepository.activeChild() {
            context.childNickname = child.name
            if let forest = try? dependencies.forestRepository.forest(for: child) {
                context.forestLevel = forest.level
            }
            let plan = try? dependencies.fetchTodayPlanUseCase.execute(
                child: child,
                preference: dependencies.appState.settings.preferredDifficulty
            )
            context.recommendedAdventure = plan?.recommendedAdventures.first
        }
        return context
    }
}
