//
//  BarakhadiView.swift
//  Focus Forest Adventure
//
//  Interactive Hindi barakhadi chart: pick a consonant, see its twelve
//  matra forms (क का कि की कु कू के कै को कौ कं कः), tap any form to
//  hear it in Hindi. Forms are generated programmatically from the
//  consonant + combining matras — no data tables needed.
//

import SwiftUI

struct BarakhadiView: View {
    let dependencies: AppDependencies

    /// Combining matras with their romanization.
    private static let matras: [(mark: String, roman: String)] = [
        ("", "a"), ("ा", "aa"), ("ि", "i"), ("ी", "ee"),
        ("ु", "u"), ("ू", "oo"), ("े", "e"), ("ै", "ai"),
        ("ो", "o"), ("ौ", "au"), ("ं", "an"), ("ः", "ah")
    ]

    /// Base consonants only (single scalar — excludes conjuncts & nuktas).
    private let consonants = HindiAlphabet.consonants
        .filter { $0.letter.unicodeScalars.count == 1 }

    @State private var selected = 0
    @State private var tappedForm: String?

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

            VStack(spacing: 12) {
                // Consonant picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(consonants.indices, id: \.self) { index in
                            Button {
                                selected = index
                                dependencies.hapticsService.playGentleTap()
                                speak(consonants[index].letter)
                            } label: {
                                Text(consonants[index].letter)
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundStyle(selected == index
                                                     ? .white : ForestTheme.Colors.deepGreen)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        Circle().fill(selected == index
                                                      ? ForestTheme.Colors.leafGreen
                                                      : ForestTheme.Colors.cloudWhite)
                                    )
                            }
                            .buttonStyle(SquishyButtonStyle())
                        }
                    }
                    .padding(.horizontal, ForestTheme.Metrics.screenPadding)
                    .padding(.vertical, 8)
                }

                // The twelve forms
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Self.matras, id: \.roman) { matra in
                            let form = consonants[selected].letter + matra.mark
                            Button {
                                tappedForm = form
                                dependencies.hapticsService.playGentleTap()
                                speak(form)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(form)
                                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                                    Text(romanized(matra))
                                        .font(ForestTheme.Fonts.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .forestCard(cornerRadius: 18)
                                .scaleEffect(tappedForm == form ? 1.1 : 1.0)
                                .animation(.bouncy(duration: 0.3), value: tappedForm)
                            }
                            .buttonStyle(SquishyButtonStyle())
                            .accessibilityLabel(form)
                        }
                    }
                    .padding(ForestTheme.Metrics.screenPadding)
                    .adaptiveContentWidth(700)
                }
            }
        }
        .navigationTitle(String(localized: "बारहखड़ी · Barakhadi"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
    }

    private func romanized(_ matra: (mark: String, roman: String)) -> String {
        let base = consonants[selected].roman.lowercased()
        // "ka" style: consonant roman minus trailing 'a' + matra sound.
        let stem = base.hasSuffix("a") ? String(base.dropLast()) : base
        return stem + matra.roman
    }

    private func speak(_ text: String) {
        Task {
            await dependencies.speechService.speak(text, language: "hi-IN")
        }
    }
}
