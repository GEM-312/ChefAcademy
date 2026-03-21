//
//  GameCenterMatchmakerView.swift
//  ChefAcademy
//
//  UIViewControllerRepresentable wrapper for GKMatchmakerViewController.
//  GameKit's matchmaker UI is UIKit-based, so we wrap it for SwiftUI.
//

import SwiftUI
import GameKit

struct GameCenterMatchmakerView: UIViewControllerRepresentable {
    let matchRequest: GKMatchRequest
    @ObservedObject var manager: MultiplayerManager

    func makeUIViewController(context: Context) -> GKMatchmakerViewController {
        guard let vc = GKMatchmakerViewController(matchRequest: matchRequest) else {
            // Fallback: return a bare VC that will be dismissed immediately
            let fallback = GKMatchmakerViewController(matchRequest: GKMatchRequest()) ?? GKMatchmakerViewController()
            fallback.matchmakerDelegate = context.coordinator
            return fallback
        }
        vc.matchmakerDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKMatchmakerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }

    class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let manager: MultiplayerManager

        init(manager: MultiplayerManager) {
            self.manager = manager
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            viewController.dismiss(animated: true)
            DispatchQueue.main.async {
                self.manager.showMatchmaker = false
                self.manager.matchPhase = .idle
            }
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            viewController.dismiss(animated: true)
            DispatchQueue.main.async {
                self.manager.showMatchmaker = false
                self.manager.matchPhase = .error("Couldn't find a match. Try again!")
            }
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            viewController.dismiss(animated: true)
            DispatchQueue.main.async {
                self.manager.didFindMatch(match)
            }
        }
    }
}
