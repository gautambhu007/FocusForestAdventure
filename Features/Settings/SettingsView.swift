//
//  SettingsView.swift
//  Focus Forest Adventure
//

import SwiftUI
import Observation

@Observable
@MainActor
final class SettingsViewModel {

    private let dependencies: AppDependencies

    var isSpeechEnabled: Bool {
        didSet {
            dependencies.appState.settings.isSpeechEnabled = isSpeechEnabled
            dependencies.speechService.isEnabled = isSpeechEnabled
            UserDefaults.standard.set(isSpeechEnabled, forKey: "settings.speech")
        }
    }
    var isMusicEnabled: Bool {
        didSet {
            dependencies.appState.settings.isMusicEnabled = isMusicEnabled
            dependencies.soundEngine.isMusicEnabled = isMusicEnabled
            UserDefaults.standard.set(isMusicEnabled, forKey: "settings.music")
        }
    }
    var isSoundEffectsEnabled: Bool {
        didSet {
            dependencies.appState.settings.isSoundEffectsEnabled = isSoundEffectsEnabled
            dependencies.soundEngine.isEffectsEnabled = isSoundEffectsEnabled
            UserDefaults.standard.set(isSoundEffectsEnabled, forKey: "settings.effects")
        }
    }
    var isColorBlindModeEnabled: Bool {
        didSet {
            dependencies.appState.settings.isColorBlindModeEnabled = isColorBlindModeEnabled
            UserDefaults.standard.set(isColorBlindModeEnabled, forKey: "settings.colorblind")
        }
    }
    var difficulty: DifficultyPreference {
        didSet {
            dependencies.appState.settings.preferredDifficulty = difficulty
            UserDefaults.standard.set(difficulty.rawValue, forKey: "settings.difficulty")
        }
    }
    var language: AppLanguage {
        didSet {
            dependencies.appState.settings.language = language
            UserDefaults.standard.set(language.rawValue, forKey: "settings.language")
        }
    }

    /// False when only the compact (robotic) system voice is installed.
    var hasNaturalVoice: Bool {
        dependencies.speechService.hasNaturalVoice
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let defaults = UserDefaults.standard
        self.isSpeechEnabled = defaults.object(forKey: "settings.speech") as? Bool ?? true
        self.isMusicEnabled = defaults.object(forKey: "settings.music") as? Bool ?? true
        self.isSoundEffectsEnabled = defaults.object(forKey: "settings.effects") as? Bool ?? true
        self.isColorBlindModeEnabled = defaults.bool(forKey: "settings.colorblind")
        self.difficulty = DifficultyPreference(
            rawValue: defaults.string(forKey: "settings.difficulty") ?? ""
        ) ?? .automatic
        self.language = AppLanguage(
            rawValue: defaults.string(forKey: "settings.language") ?? ""
        ) ?? .system
    }
}

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                Toggle(String(localized: "Bunny speaks"), isOn: $viewModel.isSpeechEnabled)
                Toggle(String(localized: "Music"), isOn: $viewModel.isMusicEnabled)
                Toggle(String(localized: "Sound effects"), isOn: $viewModel.isSoundEffectsEnabled)
            } header: {
                Text(String(localized: "Bunny's Voice & Sound"))
            } footer: {
                if !viewModel.hasNaturalVoice {
                    // iOS only ships the compact (robotic) voice; apps can't
                    // download better ones. Point parents at the free download.
                    Text(String(localized: "Bunny's voice sounds much more natural with an Enhanced voice. It's a free download: open the Settings app → Accessibility → Spoken Content → Voices, pick your language, and download an Enhanced or Premium voice. Bunny will use it automatically."))
                }
            }

            Section {
                Picker(String(localized: "Difficulty"), selection: $viewModel.difficulty) {
                    Text(String(localized: "Gentle")).tag(DifficultyPreference.gentle)
                    Text(String(localized: "Automatic (recommended)")).tag(DifficultyPreference.automatic)
                    Text(String(localized: "Adventurous")).tag(DifficultyPreference.adventurous)
                }
            } header: {
                Text(String(localized: "Learning"))
            } footer: {
                Text(String(localized: "Automatic adjusts gently based on how your child is doing. It never jumps difficulty."))
            }

            Section {
                Toggle(String(localized: "Color-blind friendly colors"), isOn: $viewModel.isColorBlindModeEnabled)
                NavigationLink(String(localized: "System accessibility settings")) {
                    AccessibilityInfoView()
                }
            } header: {
                Text(String(localized: "Accessibility"))
            } footer: {
                Text(String(localized: "The app also honors Reduce Motion, VoiceOver, and Dynamic Type automatically."))
            }

            Section(String(localized: "Language")) {
                Picker(String(localized: "Language"), selection: $viewModel.language) {
                    Text(String(localized: "System")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("Español").tag(AppLanguage.spanish)
                    Text("हिन्दी").tag(AppLanguage.hindi)
                    Text("Français").tag(AppLanguage.french)
                }
            }
        }
        .navigationTitle(String(localized: "Settings"))
    }
}

/// Explains which system accessibility features the app supports.
struct AccessibilityInfoView: View {
    var body: some View {
        List {
            Label(String(localized: "VoiceOver: every game element is labeled"), systemImage: "speaker.wave.2.bubble")
            Label(String(localized: "Reduce Motion: particles & floating disabled"), systemImage: "figure.walk.motion")
            Label(String(localized: "Dynamic Type: all text scales"), systemImage: "textformat.size")
            Label(String(localized: "Large tap targets: minimum 64 points"), systemImage: "hand.tap")
            Label(String(localized: "Color-blind support: colors always paired with symbols"), systemImage: "eye")
        }
        .navigationTitle(String(localized: "Accessibility"))
    }
}
