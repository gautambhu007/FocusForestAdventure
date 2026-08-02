//
//  BunnyAssistantView.swift
//  Focus Forest Adventure
//
//  Phase 2.2: the "Talk to Bunny" screen. Chat bubbles, tap-to-ask chips,
//  and (on supported devices) a tap-to-talk mic. Voice is optional — chips
//  make every conversation possible without it.
//

import SwiftUI

struct BunnyAssistantView: View {
    @State var viewModel: BunnyAssistantViewModel

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .glade, legibility: 0.2)

            VStack(spacing: 0) {
                bunnyHeader

                conversation

                if viewModel.voice.isListening {
                    listeningBanner
                }

                suggestionChips

                if viewModel.voice.isAvailable {
                    micButton
                        .padding(.bottom, 12)
                }
            }
            .adaptiveContentWidth(760)
        }
        .navigationTitle(String(localized: "Talk to Bunny"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .onDisappear {
            viewModel.voice.stopListening()
            viewModel.dependencies.speechService.stop()
        }
    }

    // MARK: Bunny

    private var bunnyHeader: some View {
        LottieView(
            animation: viewModel.isThinking ? .bunnyThinking : .bunnyWave,
            loopMode: .loop
        )
        .frame(width: 130, height: 130)
        .padding(.top, 4)
        .accessibilityHidden(true)
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.history.turns) { turn in
                        bubble(for: turn)
                            .id(turn.id)
                    }
                    if viewModel.isThinking {
                        HStack {
                            Text(String(localized: "Bunny is thinking…"))
                                .font(ForestTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.history.turns.count) {
                if let last = viewModel.history.turns.last {
                    withAnimation(.smooth(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func bubble(for turn: ConversationTurn) -> some View {
        HStack {
            if turn.speaker == .child { Spacer(minLength: 40) }

            Text(turn.text)
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(turn.speaker == .bunny
                                 ? ForestTheme.Colors.deepGreen
                                 : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(turn.speaker == .bunny
                              ? AnyShapeStyle(.background)
                              : AnyShapeStyle(ForestTheme.Colors.leafGreen))
                )
                .fixedSize(horizontal: false, vertical: true)

            if turn.speaker == .bunny { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(turn.speaker == .bunny
                            ? String(localized: "Bunny says: \(turn.text)")
                            : String(localized: "You said: \(turn.text)"))
    }

    // MARK: Voice

    private var listeningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text(viewModel.voice.transcript.isEmpty
                 ? String(localized: "Bunny is listening…")
                 : viewModel.voice.transcript)
                .lineLimit(2)
        }
        .font(ForestTheme.Fonts.caption)
        .foregroundStyle(ForestTheme.Colors.deepGreen)
        .padding(10)
        .forestCard(cornerRadius: 14)
        .padding(.horizontal)
        .transition(.opacity)
    }

    private var micButton: some View {
        Button {
            Task { await viewModel.micTapped() }
        } label: {
            Image(systemName: viewModel.voice.isListening ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(viewModel.voice.isListening
                                 ? ForestTheme.Colors.sunshine
                                 : ForestTheme.Colors.leafGreen)
                .background(Circle().fill(.background).padding(6))
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(viewModel.voice.isListening
                            ? String(localized: "Stop listening")
                            : String(localized: "Talk to Bunny"))
    }

    // MARK: Chips

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        Task { await viewModel.ask(suggestion) }
                    } label: {
                        Text(suggestion)
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .forestCard(cornerRadius: 20)
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .disabled(viewModel.isThinking)
    }
}
