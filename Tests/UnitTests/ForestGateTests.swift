//
//  ForestGateTests.swift
//  FocusForestAdventureTests
//
//  The rules that decide when the Magic Forest opens, what a child earns
//  for answering questions, and that the plant and treasure catalogs are
//  internally consistent.
//

import XCTest
@testable import FocusForestAdventure

// MARK: - Earning treasures

final class TreasureEngineTests: XCTestCase {

    let engine = TreasureEngine()

    func testFinishingAMissionAlwaysEarnsSomething() {
        // Effort is what counts: even a rough mission opens the forest.
        let earned = engine.award(alreadyEarned: [], accuracy: 0.2, questionsAnswered: 6)
        XCTAssertEqual(earned.count, 1, "Every finished mission must earn at least one treasure")
    }

    func testStrongMissionEarnsABonusTreasure() {
        let earned = engine.award(alreadyEarned: [], accuracy: 0.9, questionsAnswered: 20)
        XCTAssertEqual(earned.count, 2, "A strong, long mission earns a bonus treasure")
    }

    func testHighAccuracyOnAShortMissionDoesNotEarnBonus() {
        // Three perfect answers is not the same achievement as twenty.
        let earned = engine.award(alreadyEarned: [], accuracy: 1.0, questionsAnswered: 3)
        XCTAssertEqual(earned.count, 1)
    }

    func testAnsweringNothingEarnsNothing() {
        let earned = engine.award(alreadyEarned: [], accuracy: 0, questionsAnswered: 0)
        XCTAssertTrue(earned.isEmpty, "Opening and closing a mission must not earn a visit")
    }

    func testTreasuresNeverRepeat() {
        var owned: Set<String> = []
        for _ in 0..<20 {
            let earned = engine.award(alreadyEarned: owned, accuracy: 0.5, questionsAnswered: 8)
            for treasure in earned {
                XCTAssertFalse(owned.contains(treasure.id),
                               "\(treasure.id) was awarded twice")
                owned.insert(treasure.id)
            }
        }
        XCTAssertEqual(owned.count, 20)
    }

    func testAwardsFollowCatalogOrder() {
        let first = engine.award(alreadyEarned: [], accuracy: 0.5, questionsAnswered: 8)
        XCTAssertEqual(first.first?.id, TreasureCatalog.all.first?.id,
                       "The first treasure earned should be the first in the catalog")
    }

    func testRunningOutOfTreasuresIsSafe() {
        let everything = Set(TreasureCatalog.all.map(\.id))
        let earned = engine.award(alreadyEarned: everything, accuracy: 1.0, questionsAnswered: 30)
        XCTAssertTrue(earned.isEmpty, "A completed collection must not crash or duplicate")
        XCTAssertEqual(engine.passesEarned(for: earned), 0)
    }

    func testOneTreasureBuysOneVisit() {
        let earned = engine.award(alreadyEarned: [], accuracy: 0.9, questionsAnswered: 20)
        XCTAssertEqual(engine.passesEarned(for: earned), earned.count)
    }
}

// MARK: - The gate itself

final class MagicForestRulesTests: XCTestCase {

    func testForestIsClosedUntilSomethingIsEarned() {
        XCTAssertFalse(MagicForestRules.canEnter(passes: 0),
                       "With nothing earned the forest must stay shut")
        XCTAssertTrue(MagicForestRules.canEnter(passes: 1))
    }

    func testVisitIsFourMinutes() {
        XCTAssertEqual(MagicForestRules.visitDuration, 240)
    }

    func testChildIsWarnedBeforeTheVisitEnds() {
        XCTAssertGreaterThan(MagicForestRules.warningTime, 0)
        XCTAssertLessThan(MagicForestRules.warningTime, MagicForestRules.visitDuration,
                          "The warning must land inside the visit, not after it")
    }
}

// MARK: - Catalog integrity

final class TreasureCatalogTests: XCTestCase {

    func testIDsAreUnique() {
        let ids = TreasureCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate treasure IDs would be awarded twice")
    }

    func testOrderIsSequential() {
        for (index, treasure) in TreasureCatalog.all.enumerated() {
            XCTAssertEqual(treasure.order, index)
        }
    }

    func testEveryTreasureIsReachableByID() {
        for treasure in TreasureCatalog.all {
            XCTAssertEqual(TreasureCatalog.treasure(treasure.id)?.id, treasure.id)
        }
    }

    func testEveryPlacementHasSomethingToEarn() {
        let owned = Set(TreasureCatalog.all.map(\.id))
        for placement in TreasurePlacement.allCases {
            XCTAssertFalse(TreasureCatalog.treasures(for: placement, earned: owned).isEmpty,
                           "Nothing ever appears in \(placement.rawValue)")
        }
    }

    func testEveryTreasureHasChildFacingText() {
        for treasure in TreasureCatalog.all {
            XCTAssertFalse(treasure.name.isEmpty, "\(treasure.id) has no name")
            XCTAssertFalse(treasure.blurb.isEmpty, "\(treasure.id) has no blurb")
            XCTAssertFalse(treasure.emoji.isEmpty, "\(treasure.id) has no emoji")
        }
    }
}

final class PlantCatalogTests: XCTestCase {

    func testCatalogHasOverAHundredSpecies() {
        XCTAssertGreaterThan(PlantCatalog.all.count, 100,
                             "The forest should hold well over a hundred kinds of plant")
    }

    func testKeysAreUnique() {
        let keys = PlantCatalog.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "Duplicate keys collide in the lookup table")
    }

    func testNamedSpeciesArePresent() {
        // The three the brief called out by name.
        for key in ["lemongrass", "mulberry", "cherry"] {
            XCTAssertNotNil(PlantCatalog.plant(key), "\(key) is missing from the catalog")
        }
    }

    func testEverySpeciesHasATeachableFact() {
        for species in PlantCatalog.all {
            XCTAssertFalse(species.fact.isEmpty, "\(species.key) has no fact to tell")
            XCTAssertFalse(species.name.isEmpty, "\(species.key) has no name")
            XCTAssertGreaterThan(species.height, 0, "\(species.key) has no height")
        }
    }

    func testUnderstoryAndCanopyPartitionTheCatalog() {
        XCTAssertEqual(PlantCatalog.understory.count + PlantCatalog.canopy.count,
                       PlantCatalog.all.count,
                       "Every species must be scattered as either understory or canopy")
    }

    func testEveryFormIsActuallyUsed() {
        let used = Set(PlantCatalog.all.map(\.form))
        for form in PlantForm.allCases {
            XCTAssertTrue(used.contains(form),
                          "No species uses the \(form.rawValue) form — dead geometry")
        }
    }
}
