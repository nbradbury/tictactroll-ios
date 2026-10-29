import Foundation

enum Team: Sendable {
    case a, b

    var other: Team { self == .a ? .b : .a }
}

enum Difficulty: Sendable { case easy, medium, hard }

typealias Board = [Team?]

/// `winner` is nil for a draw.
struct GameResult: Equatable, Sendable {
    let winner: Team?
    let line: [Int]

    var isDraw: Bool { winner == nil }
}

let lines: [[Int]] = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
]

let columns = 3
let cells = columns * columns
private let center = 4
private let winScore = 10
private let mediumRandomMoveChance: Float = 0.2

let emptyBoard: Board = Array(repeating: nil, count: cells)

func judge(_ board: Board) -> GameResult? {
    for line in lines {
        if let t = board[line[0]], t == board[line[1]], t == board[line[2]] {
            return GameResult(winner: t, line: line)
        }
    }
    return board.allSatisfy { $0 != nil } ? GameResult(winner: nil, line: []) : nil
}

enum Rules: Sendable {
    case classic

    /// Each team keeps at most `rollingLimit` trolls; placing another makes its oldest leave, unless the move wins,
    /// even with that oldest troll in the line. No draws.
    case rolling
}

let rollingLimit = 3

/// Rolling games can go on forever, so the CPU looks this many moves ahead and calls anything deeper even.
private let rollingSearchDepth = 6

/// A board plus the order its trolls were placed in, oldest first, which `Rules.rolling` needs.
struct Position: Equatable, Sendable {
    var board: Board = emptyBoard
    var history: [Int] = []

    /// The troll `team` loses when it next places one under `rules`, or nil.
    func leavingNext(_ team: Team, _ rules: Rules) -> Int? {
        guard rules == .rolling, board.filter({ $0 == team }).count >= rollingLimit else { return nil }
        return history.first { board[$0] == team }
    }

    func play(_ cell: Int, _ team: Team, _ rules: Rules) -> Position {
        var placed = board
        placed[cell] = team
        // The win is checked first, so a line the bored troll is part of still counts and it doesn't leave.
        guard let leaving = leavingNext(team, rules), judge(placed)?.winner != team else {
            return Position(board: placed, history: history + [cell])
        }
        placed[leaving] = nil
        return Position(board: placed, history: history.filter { $0 != leaving } + [cell])
    }
}

/// The first empty cell where `team` wins on its next move, allowing for a troll leaving under `rules`, or nil.
func winningMove(_ position: Position, _ team: Team, _ rules: Rules) -> Int? {
    position.board.indices.first {
        position.board[$0] == nil && judge(position.play($0, team, rules).board)?.winner == team
    }
}

private func minimax(_ position: Position, turn: Team, me: Team, rules: Rules, depth: Int) -> Int {
    if let result = judge(position.board) {
        switch result.winner {
        case me: return winScore - depth
        case nil: return 0
        default: return depth - winScore
        }
    }
    if rules == .rolling && depth >= rollingSearchDepth { return 0 }
    let scores = position.board.indices
        .filter { position.board[$0] == nil }
        .map { minimax(position.play($0, turn, rules), turn: turn.other, me: me, rules: rules, depth: depth + 1) }
    return turn == me ? scores.max()! : scores.min()!
}

/// Picks a move for the CPU, which always plays `me` (Bramble / B in the game).
func cpuPick(
    _ position: Position,
    _ difficulty: Difficulty,
    using random: inout some RandomNumberGenerator,
    me: Team = .b,
    rules: Rules = .classic
) -> Int {
    let board = position.board
    let free = board.indices.filter { board[$0] == nil }
    switch difficulty {
    case .easy:
        return free.randomElement(using: &random)!
    case .medium:
        var move = winningMove(position, me, rules) ?? winningMove(position, me.other, rules)
        if move == nil || Float.random(in: 0..<1, using: &random) < mediumRandomMoveChance {
            move = board[center] != nil ? free.randomElement(using: &random)! : center
        }
        return move!
    case .hard:
        // Like Kotlin's maxBy, the first of equally good moves wins.
        var best = free[0]
        var bestScore = Int.min
        for cell in free {
            let score = minimax(position.play(cell, me, rules), turn: me.other, me: me, rules: rules, depth: 0)
            if score > bestScore {
                best = cell
                bestScore = score
            }
        }
        return best
    }
}

func cpuPick(_ position: Position, _ difficulty: Difficulty, me: Team = .b, rules: Rules = .classic) -> Int {
    var random = SystemRandomNumberGenerator()
    return cpuPick(position, difficulty, using: &random, me: me, rules: rules)
}
