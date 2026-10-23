//
//  VeggieJourney.swift
//  ChefAcademy
//
//  One veggie's whole trip through the game, worked out from what GameState
//  already saves: seeds in the bag → spots in the garden → wheelbarrow →
//  pantry → cooked. Nothing new is saved.
//
//  It's the single source of truth for what Pip says about the garden. The
//  Pip Plus garden tool (Haiku), the chat tool (Claude) and the free built-in
//  line all read it, so none of them can contradict the garden. (Oct 23 2026:
//  Pip said "plant broccoli" while broccoli was ready in a spot.)
//
//  TEACHING MOMENT: Code decides, the model words it.
//  Each journey carries a next step that CODE picked ("dig it up with the
//  shovel"). A model handed that step can phrase it any way it likes, but it
//  can't choose the wrong action. Facts + a decided next step make a better
//  tool result than raw facts the model must reason about.
//

import SwiftUI

struct VeggieJourney {
    /// One planting spot holding this veggie
    struct Spot {
        let number: Int          // 1-based, for the AI's reasoning only; kids never see numbers
        let state: PlotState
        let progress: Double     // 0...1
    }

    let veggie: VegetableType
    let seeds: Int
    let spots: [Spot]
    let inWheelbarrow: Int
    let inPantry: Int
    /// Recipes already cooked with this veggie, with the best stars earned
    let cookedIn: [(title: String, stars: Int)]
    /// Unlocked recipes with this veggie the kid can cook right now
    let cookableNow: [String]
    /// An empty spot is open in the unlocked rows (so planting is possible)
    let hasEmptySpot: Bool

    // MARK: - Next step (code decides)

    /// The next thing to do with this veggie, most urgent first. nil = nothing
    /// to do right now (e.g. it's just growing). `urgency` orders veggies
    /// against each other: lower = more urgent.
    var nextStep: (urgency: Int, text: String)? {
        if spots.contains(where: { $0.state == .needsWater }) {
            return (1, "water it: fill the watering can, then tap the plant")
        }
        if spots.contains(where: { $0.state == .hasBugs }) {
            return (2, "tap the ladybugs to rescue it from the bugs")
        }
        if spots.contains(where: { $0.state == .needsWeeding }) {
            return (3, "swipe up to pull the weeds")
        }
        if spots.contains(where: { $0.state == .ready }) {
            return (4, "dig it up with the shovel")
        }
        if inWheelbarrow > 0 {
            return (5, "tap the wheelbarrow to bring it to the pantry")
        }
        if let recipe = cookableNow.first {
            return (6, "cook \(recipe) in the Kitchen")
        }
        if seeds > 0 && spots.isEmpty && hasEmptySpot {
            return (7, "plant it: loosen an empty spot with the fork, then plant with the shovel")
        }
        return nil
    }

    // MARK: - Tool text

    /// One compact line for an AI tool, e.g.
    /// "Broccoli: 2 seeds · spot 3 READY to harvest · wheelbarrow 0 · pantry 0 · cooked: not yet · next: dig it up with the shovel"
    var toolLine: String {
        let location = spots.isEmpty ? "not planted" : spots.map { Self.describe($0) }.joined(separator: ", ")
        let cooked = cookedIn.isEmpty
            ? "not yet"
            : cookedIn.map { "\($0.title) \(String(repeating: "★", count: $0.stars))" }.joined(separator: ", ")
        let next = nextStep.map { "next: \($0.text)" } ?? "next: nothing, it's growing"
        return "\(veggie.displayName): \(seeds) seed\(seeds == 1 ? "" : "s") · \(location) · wheelbarrow \(inWheelbarrow) · pantry \(inPantry) · cooked: \(cooked) · \(next)"
    }

    private static func describe(_ spot: Spot) -> String {
        switch spot.state {
        case .ready:        return "spot \(spot.number) READY to harvest"
        case .needsWater:   return "spot \(spot.number) needs water"
        case .needsWeeding: return "spot \(spot.number) has weeds"
        case .hasBugs:      return "spot \(spot.number) has bugs"
        case .growing:      return "spot \(spot.number) growing \(Int(spot.progress * 100))%"
        case .empty:        return "spot \(spot.number) empty"
        }
    }
}

// MARK: - Building from GameState

extension VeggieJourney {
    /// Every veggie the kid has touched (seeds, planted, harvested or cooked),
    /// in VegetableType order.
    static func all(from game: GameState) -> [VeggieJourney] {
        let openSpots = GardenPlot.unlockedRows(forLevel: game.playerLevel) * GardenPlot.spotsPerRow
        let hasEmptySpot = game.gardenPlots.prefix(openSpots).contains { $0.state == .empty }
        let unlocked = GardenRecipes.all.filter { game.unlockedRecipeIDs.contains($0.id) }

        return VegetableType.allCases.compactMap { veg in
            let spots = game.gardenPlots.filter { $0.vegetable == veg && $0.state != .empty }.map { plot in
                // A plot can reach full growth before its state flips to .ready
                let state: PlotState = plot.state == .growing && plot.isReadyToHarvest ? .ready : plot.state
                return Spot(number: plot.id + 1, state: state, progress: plot.growthProgress)
            }
            let cookedIn = GardenRecipes.all.compactMap { recipe -> (title: String, stars: Int)? in
                guard recipe.gardenIngredients.contains(veg),
                      let stars = game.recipeStars[recipe.id], stars > 0 else { return nil }
                return (recipe.title, stars)
            }
            let journey = VeggieJourney(
                veggie: veg,
                seeds: game.seeds.first { $0.vegetableType == veg }?.quantity ?? 0,
                spots: spots,
                inWheelbarrow: game.wheelbarrow.first { $0.type == veg }?.quantity ?? 0,
                inPantry: game.harvestedIngredients.first { $0.type == veg }?.quantity ?? 0,
                cookedIn: cookedIn,
                cookableNow: unlocked
                    .filter { $0.gardenIngredients.contains(veg) }
                    .filter { $0.canCookFull(harvestedIngredients: game.harvestedIngredients,
                                             pantryInventory: game.pantryInventory) }
                    .map(\.title),
                hasEmptySpot: hasEmptySpot
            )
            let touched = journey.seeds > 0 || !journey.spots.isEmpty || journey.inWheelbarrow > 0
                || journey.inPantry > 0 || !journey.cookedIn.isEmpty
            return touched ? journey : nil
        }
    }

    /// The whole garden as tool text: one line per veggie.
    static func toolText(from game: GameState) -> String {
        let lines = all(from: game).map(\.toolLine)
        return lines.isEmpty ? "No veggies yet: the kid has no seeds and nothing planted." : lines.joined(separator: "\n")
    }

    /// The single most important thing to do in the garden right now, or nil.
    static func focus(from game: GameState) -> (journey: VeggieJourney, step: String)? {
        all(from: game)
            .compactMap { j in j.nextStep.map { (journey: j, urgency: $0.urgency, step: $0.text) } }
            .min { $0.urgency < $1.urgency }
            .map { ($0.journey, $0.step) }
    }
}

// MARK: - Preview

#Preview("Veggie Journey") {
    let game = GameState()
    game.gardenPlots[0].vegetable = .broccoli
    game.gardenPlots[0].state = .ready
    game.gardenPlots[1].vegetable = .carrot
    game.gardenPlots[1].state = .needsWater
    game.wheelbarrow = [HarvestedIngredient(type: .tomato, quantity: 2)]
    game.harvestedIngredients = [HarvestedIngredient(type: .lettuce, quantity: 1)]

    return ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(VeggieJourney.toolText(from: game))
            if let focus = VeggieJourney.focus(from: game) {
                Text("Focus: \(focus.journey.veggie.displayName) → \(focus.step)")
                    .font(.AppTheme.bodyBold)
            }
        }
        .font(.AppTheme.caption)
        .foregroundColor(Color.AppTheme.darkBrown)
        .padding(AppSpacing.md)
    }
    .background(Color.AppTheme.cream)
}
