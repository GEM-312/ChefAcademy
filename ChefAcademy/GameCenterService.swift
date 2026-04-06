//
//  GameCenterService.swift
//  ChefAcademy
//
//  Centralized Game Center integration — authentication, leaderboards,
//  achievements, and UI presentation.
//
//  TEACHING MOMENT: Singleton Pattern
//  We use a shared instance so that Game Center state (authenticated,
//  access point) is consistent across the whole app. Every view that
//  needs to report a score calls GameCenterService.shared.reportScore()
//  — no need to pass the service around via @EnvironmentObject.
//
//  WHY AUTHENTICATE AT LAUNCH?
//  Apple recommends calling authenticateHandler as early as possible.
//  This does two things:
//    1. Shows the "Welcome back!" banner (builds trust with the kid)
//    2. Makes the player object available for score/achievement APIs
//  If you only authenticate when entering multiplayer, leaderboard
//  scores from solo play never get submitted.
//

import SwiftUI
import UIKit
import GameKit
import Combine

// MARK: - Leaderboard IDs
//
// These must match EXACTLY what you created in App Store Connect.
// If they don't match, submitScore silently fails — no error, no crash,
// just... nothing happens. Triple-check these strings!
//
enum LeaderboardID {
    static let healthyPicks    = "com.chefacademy.healthy_picks_high_score"
    static let insulinTetris   = "com.chefacademy.insulin_tetris_high_score"
    static let cookingMaster   = "com.chefacademy.cooking_master"
    static let totalHarvested  = "com.chefacademy.total_veggies_harvested"
}

// MARK: - Achievement IDs

enum AchievementID {
    static let firstHarvest       = "com.chefacademy.first_harvest"
    static let greenThumb         = "com.chefacademy.green_thumb"
    static let masterGardener     = "com.chefacademy.master_gardener"
    static let firstRecipe        = "com.chefacademy.first_recipe"
    static let fiveRecipes        = "com.chefacademy.five_recipes"
    static let allThreeStars      = "com.chefacademy.all_three_stars"
    static let masterChef         = "com.chefacademy.master_chef"
    static let healthyPicksPerfect = "com.chefacademy.healthy_picks_perfect"
    static let healthyPicks50     = "com.chefacademy.healthy_picks_50"
    static let insulinPro         = "com.chefacademy.insulin_pro"
    static let noFatStorage       = "com.chefacademy.no_fat_storage"
    static let fiberFriend        = "com.chefacademy.fiber_friend"
    static let firstMultiplayer   = "com.chefacademy.first_multiplayer"
    static let multiplayerWinner  = "com.chefacademy.multiplayer_winner"
    static let weekStreak         = "com.chefacademy.week_streak"
    static let monthStreak        = "com.chefacademy.month_streak"
    static let coinCollector      = "com.chefacademy.coin_collector"
    static let seedScholar        = "com.chefacademy.seed_scholar"
    static let level5             = "com.chefacademy.level_5"
    static let level10            = "com.chefacademy.level_10"
    static let fullGarden         = "com.chefacademy.full_garden"
    static let plantWhisperer     = "com.chefacademy.plant_care"

    // Social — helping & gifting
    static let helpingHand        = "com.chefacademy.helping_hand"
    static let gardenAngel        = "com.chefacademy.garden_angel"
    static let generousChef       = "com.chefacademy.generous_chef"
    static let helpStreakAch       = "com.chefacademy.help_streak"
}

// MARK: - Game Center Service

class GameCenterService: ObservableObject {
    static let shared = GameCenterService()

    @Published var isAuthenticated = false
    @Published var playerDisplayName = ""

    /// The VC that Game Center needs us to present (sign-in flow).
    /// ChefAcademyApp watches this and presents it.
    @Published var authViewController: UIViewController?

    private init() {}

    // MARK: - Authentication
    //
    // TEACHING MOMENT: authenticateHandler is a closure that Apple calls
    // multiple times:
    //   1. First call: may include a VC to present (sign-in screen)
    //   2. After sign-in: called again with vc=nil, error=nil
    //   3. If user signs out: called again with isAuthenticated=false
    //
    // You set this ONCE and Apple manages the rest. It's like setting
    // a mailbox — Apple delivers updates whenever auth state changes.
    //

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let vc = viewController {
                    // Game Center wants to show a sign-in screen
                    self.authViewController = vc
                    return
                }

                if let error = error {
                    print("[GameCenter] Auth error: \(error.localizedDescription)")
                    self.isAuthenticated = false
                    return
                }

                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    self.playerDisplayName = GKLocalPlayer.local.displayName
                    print("[GameCenter] Authenticated: \(self.playerDisplayName)")

                    // Show the Game Center access point (floating bubble)
                    // Kids can tap it to see leaderboards and achievements
                    GKAccessPoint.shared.location = .topTrailing
                    GKAccessPoint.shared.showHighlights = true
                    GKAccessPoint.shared.isActive = true
                }
            }
        }
    }

    // MARK: - Score Reporting
    //
    // TEACHING MOMENT: The modern API is GKLeaderboard.submitScore().
    // It's a static method — you don't need to load the leaderboard first.
    // The `context` parameter is extra metadata (we pass 0).
    // `leaderboardIDs` is an array — you could submit the same score
    // to multiple leaderboards in one call!
    //

    func reportScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated else {
            print("[GameCenter] Not authenticated — score not reported")
            return
        }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
                print("[GameCenter] Score \(score) submitted to \(leaderboardID)")
            } catch {
                print("[GameCenter] Score submit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievement Reporting
    //
    // TEACHING MOMENT: Achievements use percentComplete (0.0 to 100.0).
    // For simple "did it or didn't" achievements, just send 100.0.
    // For progressive ones like "Harvest 50 veggies", calculate the
    // percentage: (currentCount / targetCount) * 100.
    //
    // showsCompletionBanner = true makes Game Center pop up a banner
    // the first time the achievement hits 100%. Kids love that!
    //

    func reportAchievement(_ id: String, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }

        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        Task {
            do {
                try await GKAchievement.report([achievement])
                print("[GameCenter] Achievement \(id) reported: \(percentComplete)%")
            } catch {
                print("[GameCenter] Achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Show Game Center UI
    //
    // TEACHING MOMENT: GKGameCenterViewController is Apple's built-in
    // Game Center UI. It shows leaderboards, achievements, and the
    // player's profile. We wrap it in a UIViewControllerRepresentable
    // (see GameCenterDashboardView below) so SwiftUI can present it.
    //

    func showDashboard(from rootVC: UIViewController? = nil) {
        guard isAuthenticated else { return }

        let gcVC = GKGameCenterViewController(state: .default)
        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared

        if let rootVC = rootVC {
            rootVC.present(gcVC, animated: true)
        } else if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(gcVC, animated: true)
        }
    }

    func showLeaderboard(_ id: String) {
        guard isAuthenticated else { return }

        let gcVC = GKGameCenterViewController(
            leaderboardID: id,
            playerScope: .global,
            timeScope: .allTime
        )
        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(gcVC, animated: true)
        }
    }

    func showAchievements() {
        guard isAuthenticated else { return }

        let gcVC = GKGameCenterViewController(state: .achievements)
        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(gcVC, animated: true)
        }
    }

    // MARK: - Bulk Achievement Check
    //
    // Called after game events to check all achievement thresholds at once.
    // Safe to call frequently — Game Center ignores duplicate reports.
    //

    func checkAchievements(gameState: GameState) {
        guard isAuthenticated else { return }

        let totalHarvested = gameState.harvestedIngredients.reduce(0) { $0 + $1.quantity }
        let recipesCooked = gameState.recipeStars.count
        let threeStarCount = gameState.recipeStars.values.filter { $0 >= 3 }.count

        // Harvest milestones
        if totalHarvested >= 1 {
            reportAchievement(AchievementID.firstHarvest)
        }
        if totalHarvested >= 50 {
            reportAchievement(AchievementID.greenThumb)
        } else if totalHarvested > 0 {
            reportAchievement(AchievementID.greenThumb, percentComplete: Double(totalHarvested) / 50.0 * 100.0)
        }
        if totalHarvested >= 200 {
            reportAchievement(AchievementID.masterGardener)
        } else if totalHarvested > 0 {
            reportAchievement(AchievementID.masterGardener, percentComplete: Double(totalHarvested) / 200.0 * 100.0)
        }

        // Cooking milestones
        if recipesCooked >= 1 {
            reportAchievement(AchievementID.firstRecipe)
        }
        if recipesCooked >= 5 {
            reportAchievement(AchievementID.fiveRecipes)
        } else if recipesCooked > 0 {
            reportAchievement(AchievementID.fiveRecipes, percentComplete: Double(recipesCooked) / 5.0 * 100.0)
        }
        if threeStarCount >= 10 {
            reportAchievement(AchievementID.allThreeStars)
        } else if threeStarCount > 0 {
            reportAchievement(AchievementID.allThreeStars, percentComplete: Double(threeStarCount) / 10.0 * 100.0)
        }
        if recipesCooked >= 17 {
            reportAchievement(AchievementID.masterChef)
        }

        // Level milestones
        if gameState.playerLevel >= 5 {
            reportAchievement(AchievementID.level5)
        }
        if gameState.playerLevel >= 10 {
            reportAchievement(AchievementID.level10)
        }

        // Garden milestones
        let plantedPlots = gameState.gardenPlots.filter { $0.vegetable != nil }.count
        if plantedPlots >= 5 {
            reportAchievement(AchievementID.fullGarden)
        }

        // Coin milestone
        if gameState.coins >= 500 {
            reportAchievement(AchievementID.coinCollector)
        }

        // Social milestones — helping & gifting
        if gameState.helpGivenCount >= 1 {
            reportAchievement(AchievementID.helpingHand)
        }
        if gameState.helpGivenCount >= 10 {
            reportAchievement(AchievementID.gardenAngel)
        } else if gameState.helpGivenCount > 0 {
            reportAchievement(AchievementID.gardenAngel, percentComplete: Double(gameState.helpGivenCount) / 10.0 * 100.0)
        }
        if gameState.helpStreak >= 3 {
            reportAchievement(AchievementID.helpStreakAch)
        }
        if gameState.giftsGivenCount >= 1 {
            reportAchievement(AchievementID.generousChef)
        }

        // Report cumulative leaderboard scores
        if totalHarvested > 0 {
            reportScore(totalHarvested, leaderboardID: LeaderboardID.totalHarvested)
        }
        if threeStarCount > 0 {
            reportScore(threeStarCount, leaderboardID: LeaderboardID.cookingMaster)
        }
    }
}

// MARK: - Dismiss Handler
//
// TEACHING MOMENT: GKGameCenterViewController requires a delegate
// to handle dismissal. This is a UIKit pattern — the delegate gets
// called when the user taps "Done". We use a shared singleton so
// we don't need to create a new one each time.
//

class GameCenterDismissHandler: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismissHandler()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

// MARK: - SwiftUI Wrapper for Game Center Dashboard
//
// Use this as a .sheet or .fullScreenCover:
//   .sheet(isPresented: $showGameCenter) { GameCenterDashboardView() }
//

struct GameCenterDashboardView: UIViewControllerRepresentable {
    var state: GKGameCenterViewControllerState = .default

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
