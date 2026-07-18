//
//  HindiAlphabetView.swift
//  Focus Forest Adventure
//
//  Hindi varnamala explorer: a grid of Devanagari letters; tapping one
//  opens a big flash card — letter, emoji picture, example word with
//  transliteration — narrated in Hindi ("क! क से कबूतर!").
//  Fully offline: emoji illustrations, on-device hi-IN speech.
//

import SwiftUI
import UIKit

struct HindiAlphabetView: View {
    let dependencies: AppDependencies

    @State private var selectedIndex: Int?
    @State private var sparkleTrigger = 0
    @State private var letterPulse = false

    private let letters = HindiAlphabet.letters
    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 110), spacing: 12)]

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "हिंदी वर्णमाला"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    Text(String(localized: "Tap a letter to meet its word!"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))

                    if !dependencies.speechService.hasHindiVoice {
                        Label(
                            String(localized: "For correct Hindi pronunciation, install the Hindi voice: Settings → Accessibility → Spoken Content → Voices → Hindi."),
                            systemImage: "speaker.wave.2.bubble"
                        )
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(12)
                        .forestCard(cornerRadius: 14)
                    }

                    sectionHeader(String(localized: "स्वर · Vowels"))
                    letterGrid(offset: 0, letters: HindiAlphabet.vowels)

                    sectionHeader(String(localized: "व्यंजन · Consonants"))
                    letterGrid(offset: HindiAlphabet.vowels.count, letters: HindiAlphabet.consonants)
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)
            }

            // Flash card overlay
            if let index = selectedIndex {
                letterCard(letters[index], index: index)
            }
        }
        .navigationTitle(String(localized: "Hindi Letters"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
        .animation(.bouncy(duration: 0.4), value: selectedIndex)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ForestTheme.Fonts.heading)
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func letterGrid(offset: Int, letters sectionLetters: [HindiLetter]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sectionLetters.indices, id: \.self) { localIndex in
                let letter = sectionLetters[localIndex]
                Button {
                    open(offset + localIndex)
                } label: {
                    VStack(spacing: 2) {
                        Text(letter.letter)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(letter.roman)
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .forestCard(cornerRadius: 18)
                }
                .buttonStyle(SquishyButtonStyle())
                .accessibilityLabel("\(letter.letter), \(letter.roman)")
            }
        }
    }

    // MARK: Flash card

    private func letterCard(_ letter: HindiLetter, index: Int) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { selectedIndex = nil }

            // Celebration sparkles whenever a new letter opens.
            SparkleBurstView(trigger: sparkleTrigger)

            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(letter.letter)
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .scaleEffect(letterPulse ? 1.15 : 1.0)
                        .animation(.bouncy(duration: 0.35), value: letterPulse)
                    Text(letter.roman)
                        .font(ForestTheme.Fonts.heading)
                        .foregroundStyle(.secondary)
                }

                // Bundled illustration when available; custom-drawn art for
                // words without an emoji (अनार); emoji otherwise.
                Group {
                    if UIImage(named: letter.imageName) != nil {
                        Image(letter.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                    } else if letter.imageName == "hindi_anaar" {
                        PomegranateArt()
                            .frame(width: 140, height: 140)
                    } else if letter.imageName == "hindi_charkhaa" {
                        CharkhaArt()
                            .frame(width: 140, height: 140)
                    } else {
                        Text(letter.emoji)
                            .font(.system(size: 110))
                    }
                }
                .floating(amplitude: 8, period: 1.8)

                if letter.isSoundOnly {
                    Text(String(localized: "विशेष ध्वनि"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Text(letter.wordMeaning)
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text(letter.word)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Text("\(letter.wordRoman) · \(letter.wordMeaning)")
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    navButton("chevron.left", enabled: index > 0) { open(index - 1) }

                    Button {
                        speak(letter)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(ForestTheme.Colors.leafGreen))
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel(String(localized: "Hear it again"))

                    navButton("chevron.right", enabled: index < letters.count - 1) { open(index + 1) }
                }
                .padding(.top, 4)

                Button {
                    selectedIndex = nil
                } label: {
                    Text(String(localized: "Done"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .forestCard(cornerRadius: 16)
                }
                .buttonStyle(SquishyButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(ForestTheme.Colors.cloudWhite)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
            .padding(24)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(letter.isSoundOnly
                                ? "\(letter.letter). \(letter.wordMeaning)"
                                : "\(letter.letter). \(letter.word). \(letter.wordRoman), \(letter.wordMeaning)")
        }
    }

    private func navButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .frame(width: 52, height: 52)
                .forestCard(cornerRadius: 16)
        }
        .buttonStyle(SquishyButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }


    // MARK: Actions

    private func open(_ index: Int) {
        selectedIndex = index
        sparkleTrigger += 1
        dependencies.hapticsService.playGentleTap()
        speak(letters[index])
    }

    private func speak(_ letter: HindiLetter) {
        letterPulse = true
        Task {
            await dependencies.speechService.speak(letter.spokenText, language: "hi-IN")
            try? await Task.sleep(for: .seconds(0.4))
            letterPulse = false
        }
    }
}

// MARK: - Custom art

/// A flat, kid-friendly pomegranate drawn in SwiftUI — Unicode has no
/// pomegranate emoji, and अ से अनार is non-negotiable.
struct PomegranateArt: View {
    private let skinDark = Color(red: 0.62, green: 0.10, blue: 0.12)
    private let skin = Color(red: 0.86, green: 0.22, blue: 0.20)
    private let flesh = Color(red: 0.99, green: 0.82, blue: 0.78)
    private let seed = Color(red: 0.78, green: 0.12, blue: 0.22)

    var body: some View {
        ZStack {
            // Crown (calyx)
            Image(systemName: "crown.fill")
                .font(.system(size: 30))
                .foregroundStyle(skinDark)
                .offset(y: -60)

            // Body
            Circle()
                .fill(LinearGradient(colors: [skin, skinDark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 116, height: 116)
                .offset(y: 4)

            // Cut face showing the flesh
            Circle()
                .fill(flesh)
                .frame(width: 66, height: 66)
                .offset(x: 16, y: 18)

            // Seeds (arils)
            ForEach(Array(seedOffsets.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(seed)
                    .frame(width: 13, height: 13)
                    .offset(x: point.x, y: point.y)
            }

            // Glossy highlight
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: 26, height: 26)
                .offset(x: -28, y: -24)
        }
        .accessibilityHidden(true)
    }

    private var seedOffsets: [CGPoint] {
        [CGPoint(x: 8, y: 8), CGPoint(x: 26, y: 14), CGPoint(x: 14, y: 30),
         CGPoint(x: 30, y: 30), CGPoint(x: 2, y: 22), CGPoint(x: 20, y: 2)]
    }
}

/// A Gandhi-style charkha (spinning wheel) drawn in SwiftUI: base plank,
/// big spoked drive wheel (which actually spins), drive band, and a
/// spindle with white cotton. No spinning-wheel emoji exists.
struct CharkhaArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    private let wood = Color(red: 0.55, green: 0.36, blue: 0.20)
    private let woodDark = Color(red: 0.40, green: 0.25, blue: 0.13)

    var body: some View {
        ZStack {
            // Base plank
            RoundedRectangle(cornerRadius: 5)
                .fill(wood)
                .frame(width: 124, height: 12)
                .offset(y: 56)

            // Posts holding the wheels
            RoundedRectangle(cornerRadius: 3)
                .fill(woodDark)
                .frame(width: 8, height: 46)
                .offset(x: -30, y: 32)
            RoundedRectangle(cornerRadius: 3)
                .fill(woodDark)
                .frame(width: 7, height: 28)
                .offset(x: 42, y: 42)

            // Drive band connecting the wheels
            Path { path in
                path.move(to: CGPoint(x: 40, y: 42))     // big wheel top
                path.addLine(to: CGPoint(x: 112, y: 58)) // small wheel top
                path.move(to: CGPoint(x: 40, y: 118))    // big wheel bottom
                path.addLine(to: CGPoint(x: 112, y: 82)) // small wheel bottom
            }
            .stroke(woodDark.opacity(0.7), lineWidth: 2.5)

            // Big drive wheel with spokes — it spins!
            ZStack {
                Circle()
                    .stroke(wood, lineWidth: 7)
                ForEach(0..<6, id: \.self) { spoke in
                    Rectangle()
                        .fill(woodDark)
                        .frame(width: 3, height: 72)
                        .rotationEffect(.degrees(Double(spoke) * 30))
                }
                Circle()
                    .fill(woodDark)
                    .frame(width: 12, height: 12)
            }
            .frame(width: 76, height: 76)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .offset(x: -30, y: 10)

            // Spindle wheel
            Circle()
                .stroke(wood, lineWidth: 5)
                .frame(width: 24, height: 24)
                .offset(x: 42, y: 0)

            // Spindle + cotton
            Capsule()
                .fill(.white)
                .frame(width: 30, height: 11)
                .offset(x: 52, y: -14)
            Rectangle()
                .fill(woodDark)
                .frame(width: 44, height: 2.5)
                .offset(x: 50, y: -14)
        }
        .frame(width: 140, height: 140)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
        .accessibilityHidden(true)
    }
}
