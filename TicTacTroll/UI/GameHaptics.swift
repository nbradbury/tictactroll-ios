import UIKit

/// Matches the silent lead-in on the win and loss sounds.
private let endingLeadInMs = 250

/// A light tick as each troll lands, then a success for a win or an error for losing to the CPU, timed with the
/// ending sound. Independent of the sound toggle; the system haptics setting still applies.
@MainActor
final class GameHaptics {
    private let landing = UIImpactFeedbackGenerator(style: .light)
    private let ending = UINotificationFeedbackGenerator()

    func onChange(from previous: GameState, to state: GameState) {
        if state.board.indices.contains(where: { state.board[$0] != nil && previous.board[$0] == nil }) {
            landing.prepare()
            // Timed to the troll hitting its crate at the end of its drop.
            Task { [landing] in
                guard await pause(landingMs) else { return }
                landing.impactOccurred()
            }
        }
        if previous.result == nil, let winner = state.result?.winner {
            ending.prepare()
            let playerLost = state.mode == .cpu && winner == .b
            Task { [ending] in
                guard await pause(endingLeadInMs) else { return }
                ending.notificationOccurred(playerLost ? .error : .success)
            }
        }
    }
}
