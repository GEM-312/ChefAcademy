//
//  MultiplayerManager.swift
//  ChefAcademy
//
//  GameKit (Game Center) manager for real-time multiplayer Healthy Picks.
//  Handles authentication, matchmaking, and peer-to-peer messaging.
//

import SwiftUI
import GameKit
import Combine

// MARK: - Match Phase

enum MatchPhase: Equatable {
    case idle
    case authenticating
    case matchmaking
    case connected
    case countdown(Int) // 3, 2, 1
    case playing
    case finished
    case error(String)
}

// MARK: - Multiplayer Message Protocol

enum MultiplayerMessage: Codable {
    case playerInfo(name: String, genderRaw: String, level: Int)
    case seedExchange(seed: UInt64)
    case ready
    case scoreUpdate(score: Int, goodChoices: Int, badChoices: Int)
    case gameFinished(finalScore: Int, goodChoices: Int, badChoices: Int)
}

// MARK: - Multiplayer Manager

class MultiplayerManager: NSObject, ObservableObject {
    @Published var matchPhase: MatchPhase = .idle
    @Published var opponentName: String = ""
    @Published var opponentGender: Gender = .girl
    @Published var opponentLevel: Int = 1
    @Published var opponentScore: Int = 0
    @Published var opponentGoodChoices: Int = 0
    @Published var opponentBadChoices: Int = 0
    @Published var opponentFinished: Bool = false
    @Published var opponentFinalScore: Int = 0
    @Published var isHost: Bool = false
    @Published var gameSeed: UInt64 = 0
    @Published var localReady: Bool = false
    @Published var opponentReady: Bool = false
    @Published var showMatchmaker: Bool = false
    @Published var authViewController: UIViewController?

    private var match: GKMatch?
    private var opponentPlayer: GKPlayer?
    private var countdownTimer: Timer?

    // MARK: - Authentication

    func authenticateLocalPlayer() {
        matchPhase = .authenticating

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let vc = viewController {
                    // Need to show Game Center sign-in
                    self.authViewController = vc
                    return
                }

                if let error = error {
                    print("[Multiplayer] Auth error: \(error.localizedDescription)")
                    self.matchPhase = .error("Ask a grown-up to turn on Game Center in Settings!")
                    return
                }

                if GKLocalPlayer.local.isAuthenticated {
                    print("[Multiplayer] Authenticated as: \(GKLocalPlayer.local.displayName)")
                    self.matchPhase = .idle
                } else {
                    self.matchPhase = .error("Game Center is not available.")
                }
            }
        }
    }

    // MARK: - Matchmaking

    func startMatchmaking() {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateLocalPlayer()
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2

        matchPhase = .matchmaking
        showMatchmaker = true
    }

    func didFindMatch(_ match: GKMatch) {
        self.match = match
        match.delegate = self
        showMatchmaker = false

        // Determine host by comparing player IDs
        if let opponent = match.players.first {
            opponentPlayer = opponent
            isHost = GKLocalPlayer.local.gamePlayerID < opponent.gamePlayerID
            print("[Multiplayer] Match found! Host: \(isHost), opponent: \(opponent.displayName)")
        }

        // Don't send data yet — wait for didChangeConnectionState to confirm
        // the peer-to-peer channel is actually ready (expectedPlayerCount == 0)
        print("[Multiplayer] Waiting for peer-to-peer connection... expectedPlayerCount: \(match.expectedPlayerCount)")

        // If all players are already connected, start immediately
        if match.expectedPlayerCount == 0 {
            beginDataExchange()
        }
        // Otherwise, didChangeConnectionState will call beginDataExchange
    }

    /// Called once the peer-to-peer data channel is confirmed ready
    private func beginDataExchange() {
        guard matchPhase != .connected else { return } // prevent double-fire
        matchPhase = .connected

        print("[Multiplayer] Peer-to-peer ready — starting data exchange")

        // Send player info
        sendPlayerInfo()

        // Host generates and sends the seed
        if isHost {
            gameSeed = UInt64.random(in: 1...UInt64.max)
            sendMessage(.seedExchange(seed: gameSeed))
            print("[Multiplayer] Host sent seed: \(gameSeed)")
        }
    }

    // MARK: - Send Messages

    private func sendMessage(_ message: MultiplayerMessage) {
        guard let match = match else { return }

        do {
            let data = try JSONEncoder().encode(message)
            // Use reliable for all messages (game is low-frequency enough)
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            print("[Multiplayer] Send error: \(error.localizedDescription)")
        }
    }

    /// Profile data set by the view before matchmaking
    var localName: String = ""
    var localGenderRaw: String = "Girl"
    var localLevel: Int = 1

    private func sendPlayerInfo() {
        // Use Game Center display name so each device sends a unique identity
        // (app profile names can be identical when CloudKit syncs family data)
        let name = GKLocalPlayer.local.displayName
        sendMessage(.playerInfo(name: name, genderRaw: localGenderRaw, level: localLevel))
    }

    func setLocalPlayerInfo(name: String, gender: Gender, level: Int) {
        localName = name
        localGenderRaw = gender.rawValue
        localLevel = level
    }

    func sendReady() {
        localReady = true
        sendMessage(.ready)
        checkBothReady()
    }

    func sendScoreUpdate(score: Int, goodChoices: Int, badChoices: Int) {
        sendMessage(.scoreUpdate(score: score, goodChoices: goodChoices, badChoices: badChoices))
    }

    func sendGameFinished(finalScore: Int, goodChoices: Int, badChoices: Int) {
        sendMessage(.gameFinished(finalScore: finalScore, goodChoices: goodChoices, badChoices: badChoices))
    }

    // MARK: - Receive Messages

    private func handleMessage(_ message: MultiplayerMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch message {
            case .playerInfo(let name, let genderRaw, let level):
                self.opponentName = name
                self.opponentGender = Gender(rawValue: genderRaw) ?? .girl
                self.opponentLevel = level
                print("[Multiplayer] Opponent info: \(name), \(genderRaw), level \(level)")

            case .seedExchange(let seed):
                self.gameSeed = seed
                print("[Multiplayer] Received seed: \(seed)")

            case .ready:
                self.opponentReady = true
                self.checkBothReady()

            case .scoreUpdate(let score, let good, let bad):
                withAnimation(AnimationConstants.fadeMedium) {
                    self.opponentScore = score
                    self.opponentGoodChoices = good
                    self.opponentBadChoices = bad
                }

            case .gameFinished(let score, let good, let bad):
                self.opponentFinished = true
                self.opponentFinalScore = score
                self.opponentGoodChoices = good
                self.opponentBadChoices = bad
            }
        }
    }

    // MARK: - Countdown

    private func checkBothReady() {
        guard localReady && opponentReady else { return }
        startCountdown()
    }

    private func startCountdown() {
        matchPhase = .countdown(3)
        var count = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            count -= 1
            DispatchQueue.main.async {
                if count > 0 {
                    self?.matchPhase = .countdown(count)
                } else {
                    timer.invalidate()
                    self?.countdownTimer = nil
                    self?.matchPhase = .playing
                }
            }
        }
    }

    // MARK: - Cleanup

    func disconnect() {
        match?.disconnect()
        match = nil
        opponentPlayer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        resetState()
    }

    private func resetState() {
        matchPhase = .idle
        opponentName = ""
        opponentGender = .girl
        opponentLevel = 1
        opponentScore = 0
        opponentGoodChoices = 0
        opponentBadChoices = 0
        opponentFinished = false
        opponentFinalScore = 0
        isHost = false
        gameSeed = 0
        localReady = false
        opponentReady = false
        showMatchmaker = false
    }
}

// MARK: - GKMatchDelegate

extension MultiplayerManager: GKMatchDelegate {

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        do {
            let message = try JSONDecoder().decode(MultiplayerMessage.self, from: data)
            handleMessage(message)
        } catch {
            print("[Multiplayer] Decode error: \(error.localizedDescription)")
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch state {
            case .connected:
                print("[Multiplayer] Player connected: \(player.displayName), expectedPlayerCount: \(match.expectedPlayerCount)")
                // All players connected — peer-to-peer channel is ready
                if match.expectedPlayerCount == 0 {
                    self.beginDataExchange()
                }
            case .disconnected:
                print("[Multiplayer] Player disconnected: \(player.displayName)")
                if self.matchPhase == .playing {
                    self.matchPhase = .finished
                } else if self.matchPhase == .connected || self.matchPhase == .countdown(0) {
                    self.matchPhase = .error("Your friend left the game.")
                }
            default:
                break
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            print("[Multiplayer] Match error: \(error?.localizedDescription ?? "unknown")")
            self?.matchPhase = .error("Connection lost. Try again!")
        }
    }
}
