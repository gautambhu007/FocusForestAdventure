//
//  SnapshotTests.swift
//  FocusForestAdventureSnapshotTests
//
//  Snapshot tests using pointfreeco/swift-snapshot-testing.
//  Run once with `isRecording = true` to record reference images.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import FocusForestAdventure

@MainActor
final class DesignSystemSnapshotTests: XCTestCase {

    private func assertSnapshot<V: View>(
        of view: V,
        named name: String,
        size: CGSize = CGSize(width: 393, height: 852),   // iPhone 15 Pro
        file: StaticString = #filePath,
        testName: String = #function
    ) {
        let host = UIHostingController(rootView: view.frame(width: size.width, height: size.height))
        SnapshotTesting.assertSnapshot(
            of: host, as: .image(size: size), named: name,
            file: file, testName: testName
        )
    }

    func testBigBouncyButton() {
        assertSnapshot(
            of: BigBouncyButton(title: "Adventure!", icon: "map.fill",
                                color: ForestTheme.Colors.sunshine) {},
            named: "default",
            size: CGSize(width: 320, height: 120)
        )
    }

    func testAdventureCards() {
        let grid = LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(AdventureKind.allCases, id: \.self) { kind in
                AdventureCard(adventure: kind) {}
            }
        }
        .padding()
        .background(ForestTheme.Gradients.magic)
        assertSnapshot(of: grid, named: "all_adventures")
    }

    func testForestProgressBar() {
        let stack = VStack(spacing: 24) {
            ForestProgressBar(progress: 0)
            ForestProgressBar(progress: 0.5)
            ForestProgressBar(progress: 1)
        }
        .padding()
        assertSnapshot(of: stack, named: "progress_states", size: CGSize(width: 360, height: 260))
    }

    func testStarCounter() {
        assertSnapshot(of: StarCounter(count: 42), named: "42_stars",
                       size: CGSize(width: 140, height: 70))
    }

    func testSpeechBubble() {
        assertSnapshot(
            of: SpeechBubble(text: "Hello Explorer! Ready for an adventure?"),
            named: "welcome",
            size: CGSize(width: 360, height: 160)
        )
    }

    // Dynamic Type: verify layout at accessibility text sizes.
    func testBigBouncyButtonAccessibilityXXL() {
        let view = BigBouncyButton(title: "Adventure!", icon: "map.fill",
                                   color: ForestTheme.Colors.sunshine) {}
            .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
        assertSnapshot(of: view, named: "a11y_xxl", size: CGSize(width: 393, height: 160))
    }

    // Dark mode sanity for the parent-facing surfaces.
    func testAccessibilityInfoDark() {
        let view = NavigationStack { AccessibilityInfoView() }
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, named: "dark")
    }
}
