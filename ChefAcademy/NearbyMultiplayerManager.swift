//
//  NearbyMultiplayerManager.swift
//  ChefAcademy
//
//  Nearby multiplayer using MultipeerConnectivity — connects two devices
//  over WiFi/Bluetooth without Game Center. Perfect for siblings in the same room.
//

import SwiftUI
import MultipeerConnectivity
import Combine

// MARK: - Nearby Match Phase

enum NearbyMatchPhase: Equatable {
    case idle
    case searching       // Looking for nearby player
    case connected       // Found each other
    case countdown(Int)  // 3, 2, 1
    case playing
    case waitingForOpponent // Finished, waiting for other player
    case finished
    case error(String)
}

// MARK: - Nearby Message

enum NearbyMessage: Codable {
    case playerInfo(name: String, genderRaw: String)
    case seedExchange(seed: UInt64)
    case ready
    case scoreUpdate(score: Int, goodChoices: Int, badChoices: Int)
    case gameFinished(finalScore: Int, goodChoices: Int, badChoices: Int)
}

// MARK: - Nearby Multiplayer Manager

class NearbyMultiplayerManager: NSObject, ObservableObject {
    // Service type must be 1-15 chars, lowercase + hyphens only
    private let serviceType = "pip-healthy"

    private var myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    @Published var matchPhase: NearbyMatchPhase = .idle
    @Published var opponentName: String = ""
    @Published var opponentGender: Gender = .girl
    @Published var opponentScore: Int = 0
    @Published var opponentGoodChoices: Int = 0
    @Published var opponentBadChoices: Int = 0
    @Published var opponentFinished: Bool = false
    @Published var opponentFinalScore: Int = 0
    @Published var isHost: Bool = false
    @Published var gameSeed: UInt64 = 0
    @Published var localReady: Bool = false
    @Published var opponentReady: Bool = false

    private var countdownTimer: Timer?

    var localName: String = "Player"
    var localGenderRaw: String = "Girl"

    override init() {
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    // MARK: - Start Searching

    func startSearching() {
        // Create a fresh session
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        // Both advertise AND browse — first one to find the other connects
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        matchPhase = .searching
        print("[Nearby] Started searching...")
    }

    // MARK: - Stop

    func stopSearching() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
    }

    func disconnect() {
        stopSearching()
        session?.disconnect()
        session = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        resetState()
    }

    private func resetState() {
        matchPhase = .idle
        opponentName = ""
        opponentGender = .girl
        opponentScore = 0
        opponentGoodChoices = 0
        opponentBadChoices = 0
        opponentFinished = false
        opponentFinalScore = 0
        isHost = false
        gameSeed = 0
        localReady = false
        opponentReady = false
    }

    // MARK: - Send Messages

    func sendMessage(_ message: NearbyMessage) {
        guard let session = session,
              let peer = session.connectedPeers.first else { return }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            print("[Nearby] Send error: \(error.localizedDescription)")
        }
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

    // MARK: - Receive

    private func handleMessage(_ message: NearbyMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch message {
            case .playerInfo(let name, let genderRaw):
                self.opponentName = name
                self.opponentGender = Gender(rawValue: genderRaw) ?? .girl
                print("[Nearby] Opponent: \(name)")

            case .seedExchange(let seed):
                self.gameSeed = seed
                print("[Nearby] Received seed: \(seed)")

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

    // MARK: - Connection Established

    private func handleConnection() {
        stopSearching()

        // Determine host by comparing peer names
        guard let opponent = session?.connectedPeers.first else { return }
        isHost = myPeerID.displayName < opponent.displayName

        DispatchQueue.main.async {
            self.matchPhase = .connected
        }

        // Send player info
        sendMessage(.playerInfo(name: localName, genderRaw: localGenderRaw))

        // Host generates seed
        if isHost {
            gameSeed = UInt64.random(in: 1...UInt64.max)
            sendMessage(.seedExchange(seed: gameSeed))
            print("[Nearby] Host sent seed: \(gameSeed)")
        }
    }
}

// MARK: - MCSessionDelegate

extension NearbyMultiplayerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("[Nearby] Connected to: \(peerID.displayName)")
                self.handleConnection()
            case .notConnected:
                print("[Nearby] Disconnected: \(peerID.displayName)")
                if case .playing = self.matchPhase {
                    self.matchPhase = .finished
                } else if case .finished = self.matchPhase {
                    // Already finished, ignore
                } else {
                    self.matchPhase = .error("Your friend disconnected.")
                }
            case .connecting:
                print("[Nearby] Connecting to: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(NearbyMessage.self, from: data)
            handleMessage(message)
        } catch {
            print("[Nearby] Decode error: \(error.localizedDescription)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbyMultiplayerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[Nearby] Received invitation from: \(peerID.displayName)")
        invitationHandler(true, session) // Auto-accept
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.matchPhase = .error("Couldn't start searching nearby.")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbyMultiplayerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("[Nearby] Found peer: \(peerID.displayName)")
        // Only invite if we haven't connected yet
        if session?.connectedPeers.isEmpty == true {
            browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 10)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[Nearby] Lost peer: \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.matchPhase = .error("Couldn't search for nearby players.")
        }
    }
}
