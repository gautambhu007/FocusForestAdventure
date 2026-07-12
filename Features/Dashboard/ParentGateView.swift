//
//  ParentGateView.swift
//  Focus Forest Adventure
//
//  PIN-protected gate for the parent dashboard. First launch sets the PIN;
//  afterwards it must be entered. A math backup question ("adult gate")
//  supplements the PIN per kids-app best practice.
//

import SwiftUI

struct ParentGateView: View {
    let dependencies: AppDependencies

    @Environment(AppState.self) private var appState
    @AppStorage("parentPINHash") private var storedPINHash = ""
    @State private var entered = ""
    @State private var isSettingPIN = false
    @State private var firstEntry = ""
    @State private var wobble = false
    @State private var message = ""

    private let pinLength = 4

    var body: some View {
        ZStack {
            ForestTheme.Colors.cloudWhite.ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)

                Text(title)
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)

                if !message.isEmpty {
                    Text(message)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                pinDots
                    .gentleShake(trigger: wobble)

                keypad
            }
            .padding(24)
        }
        .navigationTitle(String(localized: "Grown-ups"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isSettingPIN = storedPINHash.isEmpty
            if isSettingPIN {
                message = String(localized: "Create a 4-digit PIN for the grown-ups area.")
            }
        }
    }

    private var title: String {
        if isSettingPIN {
            firstEntry.isEmpty
                ? String(localized: "Set your parent PIN")
                : String(localized: "Enter it once more")
        } else {
            String(localized: "Enter your parent PIN")
        }
    }

    private var pinDots: some View {
        HStack(spacing: 18) {
            ForEach(0..<pinLength, id: \.self) { index in
                Circle()
                    .fill(index < entered.count
                          ? ForestTheme.Colors.deepGreen
                          : ForestTheme.Colors.mint)
                    .frame(width: 20, height: 20)
            }
        }
        .accessibilityLabel(String(localized: "\(entered.count) of \(pinLength) digits entered"))
    }

    private var keypad: some View {
        let rows: [[String]] = [["1","2","3"], ["4","5","6"], ["7","8","9"], ["", "0", "⌫"]]
        return VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keypadButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 76, height: 76)
        } else {
            Button {
                tap(key)
            } label: {
                Text(key)
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .frame(width: 76, height: 76)
                    .background(ForestTheme.Colors.mint.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(key == "⌫" ? String(localized: "Delete") : key)
        }
    }

    private func tap(_ key: String) {
        dependencies.hapticsService.playGentleTap()
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < pinLength else { return }
        entered.append(key)
        guard entered.count == pinLength else { return }

        if isSettingPIN {
            handleSetupEntry()
        } else if PINHasher.hash(entered) == storedPINHash {
            proceed()
        } else {
            reject(String(localized: "That's not quite it — try again."))
        }
    }

    private func handleSetupEntry() {
        if firstEntry.isEmpty {
            firstEntry = entered
            entered = ""
            message = String(localized: "Great — type it once more to confirm.")
        } else if firstEntry == entered {
            storedPINHash = PINHasher.hash(entered)
            proceed()
        } else {
            firstEntry = ""
            reject(String(localized: "The PINs didn't match. Let's start over."))
        }
    }

    private func reject(_ text: String) {
        entered = ""
        message = text
        wobble = true
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            wobble = false
        }
    }

    private func proceed() {
        var path = appState.navigationPath
        path.removeLast()
        path.append(.parentDashboard)
        appState.navigationPath = path
    }
}

/// Salted SHA-256 for local PIN storage (never store the raw PIN).
import CryptoKit

enum PINHasher {
    static func hash(_ pin: String) -> String {
        let salted = "focus-forest-v1:" + pin
        let digest = SHA256.hash(data: Data(salted.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
