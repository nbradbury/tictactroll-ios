import Foundation
import Observation

enum Screen { case menu, game }

enum Mode { case pvp, cpu }

struct Scores: Equatable {
    var a = 0
    var b = 0
    var draws = 0

    mutating func add(_ winner: Team?) {
        switch winner {
        case .a: a += 1
        case .b: b += 1
        case nil: draws += 1
        }
    }
}

/// Where a troll is looking: each of `dx` and `dy` is -1, 0 or 1 (right and down are positive).
struct Gaze: Equatable {
    var dx = 0
    var dy = 0
}

/// Troll keys: board cells use their index, the two menu trolls use `menuA` and `menuB`.
let menuA = 9
let menuB = 10

struct GameState: Equatable {
    var screen = Screen.menu
    var mode = Mode.cpu
    var difficulty = Difficulty.medium
    var rules = Rules.classic
    var board = emptyBoard
    /// Occupied cells in the order they were played, oldest first.
    var history: [Int] = []
    /// The cell a bored troll just left under `Rules.rolling`, if the last move made one leave.
    var departed: Int?
    var turn = Team.a
    var starter = Team.a
    var result: GameResult?
    var showSheet = false
    var scores = Scores()
    var gaze: [Int: Gaze] = [:]
    var bubbles: [Int: String] = [:]
    /// True during the draw sequence, when every troll stares at the player.
    var stare = false
    var locked = false
    /// Losing trolls that have popped after landing in the dirt.
    var popped: Set<Int> = []
    /// The bored troll that's mid-yawn, if any.
    var yawning: Int?
    /// A menu troll that's briefly hopping with excitement.
    var excitedTroll: Int?

    var isCpuTurn: Bool { result == nil && mode == .cpu && turn == .b }

    /// Whether a tap on an empty cell should place a troll right now.
    var acceptsMove: Bool { result == nil && !locked && !isCpuTurn }

    func isFallen(_ team: Team) -> Bool { result?.winner.map { $0 != team } ?? false }

    var position: Position { Position(board: board, history: history) }

    /// The troll that leaves when the player to move places their next one, if any.
    var leavingNext: Int? { result == nil ? position.leavingNext(turn, rules) : nil }
}

private struct Actor {
    let key: Int
    let row: Int
    let col: Int
}

private enum Timing {
    static let gaze = 750
    static let chatter = 5000
    static let cpuDelay = 650
    static let bubble = 1800
    static let excited = 1200
    static let yawnEvery = 3200
    static let yawn = 1300
    static let drawMehDelay = 350
    static let drawStare = 2600
    static let sheetDelayWin = 1600
    static let sheetDelayDraw = 2000
    static let glanceAtNeighborRoll: Float = 0.6
    static let glanceAnywhereRoll: Float = 0.85
}

@MainActor
@Observable
final class GameModel {
    private(set) var state: GameState

    /// Delayed actions tied to the current round, cancelled when a new round starts or on returning to the menu.
    @ObservationIgnored private var roundTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var taggedTasks: [String: UUID] = [:]

    init(rules: Rules = .classic) {
        state = GameState(rules: rules)
        repeatEvery(Timing.gaze) { $0.gazeTick() }
        repeatEvery(Timing.chatter) { $0.chatter() }
        repeatEvery(Timing.yawnEvery) { $0.yawn() }
    }

    /// Gorp perks up when a second player joins.
    func setMode(_ mode: Mode) {
        state.mode = mode
        if mode == .pvp {
            say(menuA, "ooh", Timing.bubble)
            excite(menuA)
        }
    }

    func setRules(_ rules: Rules) { state.rules = rules }

    /// Bramble has opinions about the difficulty: gleeful at Troll, bored at Easy.
    func setDifficulty(_ difficulty: Difficulty) {
        state.difficulty = difficulty
        switch difficulty {
        case .hard:
            say(menuB, "heh", Timing.bubble)
            excite(menuB)
        case .easy:
            say(menuB, "meh", Timing.bubble)
        case .medium:
            break
        }
    }

    private func excite(_ key: Int) {
        state.excitedTroll = key
        laterReplacing("hop", Timing.excited) { $0.state.excitedTroll = nil }
    }

    func start() {
        state.screen = .game
        state.scores = Scores()
        newRound(.a)
    }

    func toMenu() {
        clearLater()
        state.screen = .menu
        resetRound()
    }

    /// Called by the board once a losing troll has landed in the dirt, so it pops.
    func popFallen(_ index: Int) {
        guard let team = state.board[index], state.isFallen(team), !state.popped.contains(index) else { return }
        state.popped.insert(index)
        state.bubbles[index] = nil
    }

    func restart() { newRound(state.starter) }

    func rematch() { newRound(state.starter.other) }

    func play(_ index: Int) {
        guard state.acceptsMove, state.board[index] == nil else { return }
        place(index)
    }

    private func place(_ index: Int) {
        let s = state
        let before = s.position
        let after = before.play(index, s.turn, s.rules)
        let result = judge(after.board)
        let next = s.turn.other
        state.board = after.board
        state.history = after.history
        state.departed = before.leavingNext(s.turn, s.rules).flatMap { after.board[$0] == nil ? $0 : nil }
        state.turn = next
        state.result = result
        state.gaze = everyoneLooksAt(after.board, index)
        // Taking the cell the other side needed to win earns a taunt from the troll that took it.
        let blocked = judge(before.play(index, next, s.rules).board)?.winner == next
        if blocked && result == nil { say(index, "bleh", Timing.bubble) }
        if let result {
            endGame(result)
        } else if s.mode == .cpu && next == .b {
            cpuMove()
        }
    }

    /// Losers glance at the winning line before they topple; winners look down at the losers, who are headed for the
    /// dirt below.
    private func endingGazes(_ board: Board, _ winner: Team, _ line: [Int]) -> [Int: Gaze] {
        let middle = line[1]
        let losers = board.indices.filter { board[$0] == winner.other }
        let loserCol = losers.isEmpty ? 1 : Float(losers.map { $0 % columns }.reduce(0, +)) / Float(losers.count)
        var gazes: [Int: Gaze] = [:]
        for i in board.indices where board[i] != nil {
            let col = i % columns
            gazes[i] = board[i] == winner
                ? Gaze(dx: sign(loserCol - Float(col)), dy: 1)
                : Gaze(dx: sign(middle % columns - col), dy: sign(middle / columns - i / columns))
        }
        return gazes
    }

    /// Every troll on `board` turns to look at the one that just landed at `index`.
    private func everyoneLooksAt(_ board: Board, _ index: Int) -> [Int: Gaze] {
        var gazes: [Int: Gaze] = [:]
        for i in board.indices where board[i] != nil {
            gazes[i] = Gaze(dx: sign(index % columns - i % columns), dy: sign(index / columns - i / columns))
        }
        return gazes
    }

    private func cpuMove() {
        // Bramble's trolls look up and cock their heads while he "thinks".
        state.locked = true
        for i in state.board.indices where state.board[i] == .b {
            state.gaze[i] = Gaze(dx: Bool.random() ? 1 : -1, dy: -1)
        }
        later(Timing.cpuDelay) { model in
            model.state.locked = false
            let s = model.state
            model.place(cpuPick(s.position, s.difficulty, rules: s.rules))
        }
    }

    private func endGame(_ result: GameResult) {
        state.scores.add(result.winner)
        if let winner = result.winner {
            state.gaze = endingGazes(state.board, winner, result.line)
        }
        if result.isDraw {
            // A chatter bubble's pending removal would otherwise cut its troll's "meh" short. The chorus replaces
            // any showing bubbles and the stare clears them all, so nothing is left stranded.
            clearLater()
            state.stare = true
            state.gaze = Dictionary(uniqueKeysWithValues: state.board.indices.map { ($0, Gaze()) })
            later(Timing.drawMehDelay) { model in
                model.state.bubbles = Dictionary(uniqueKeysWithValues: model.state.board.indices.map { ($0, "meh") })
            }
            later(Timing.drawStare) { model in
                model.state.bubbles = [:]
                model.state.stare = false
            }
        }
        later(result.isDraw ? Timing.sheetDelayDraw : Timing.sheetDelayWin) { $0.state.showSheet = true }
    }

    private func newRound(_ starter: Team) {
        clearLater()
        resetRound()
        state.turn = starter
        state.starter = starter
        if state.mode == .cpu && starter == .b { cpuMove() }
    }

    private func resetRound() {
        state.board = emptyBoard
        state.history = []
        state.departed = nil
        state.popped = []
        state.yawning = nil
        state.result = nil
        state.showSheet = false
        state.bubbles = [:]
        state.gaze = [:]
        state.stare = false
        state.locked = false
    }

    private func actors() -> [Actor] {
        if state.screen == .menu { return [Actor(key: menuA, row: 0, col: 0), Actor(key: menuB, row: 0, col: 1)] }
        return state.board.indices.compactMap { i in
            state.board[i] == nil ? nil : Actor(key: i, row: i / columns, col: i % columns)
        }
    }

    /// One or two trolls glance at a neighbor, glance anywhere, or look straight ahead, by cumulative roll.
    private func gazeTick() {
        // Endings and Bramble's thinking pose set gazes on purpose; don't glance them away.
        let posed = state.screen == .game && (state.result != nil || state.isCpuTurn)
        if state.stare || posed { return }
        let actors = actors()
        guard !actors.isEmpty else { return }
        var gaze = state.gaze
        for _ in 0..<Int.random(in: 1...2) {
            let me = actors.randomElement()!
            let others = actors.filter { $0.key != me.key }
            let roll = Float.random(in: 0..<1)
            if let other = others.randomElement(), roll < Timing.glanceAtNeighborRoll {
                gaze[me.key] = Gaze(dx: sign(other.col - me.col), dy: sign(other.row - me.row))
            } else if roll < Timing.glanceAnywhereRoll {
                gaze[me.key] = Gaze(dx: Int.random(in: -1...1), dy: Int.random(in: -1...1))
            } else {
                gaze[me.key] = Gaze()
            }
        }
        state.gaze = gaze
    }

    /// The troll that's about to get bored stretches and yawns now and then.
    private func yawn() {
        guard let cell = state.leavingNext, state.screen == .game else { return }
        state.yawning = cell
        say(cell, "yawn", Timing.yawn)
        laterReplacing("yawn", Timing.yawn) { $0.state.yawning = nil }
    }

    private func chatter() {
        if state.stare { return }
        // Popped trolls are gone, so they've nothing left to say.
        guard let me = actors().filter({ !state.popped.contains($0.key) }).randomElement() else { return }
        say(me.key, ["bleh", "meh"].randomElement()!, Timing.bubble)
    }

    private func say(_ key: Int, _ text: String, _ ms: Int) {
        state.bubbles[key] = text
        laterReplacing("bubble\(key)", ms) { $0.state.bubbles[key] = nil }
    }

    @discardableResult
    private func later(_ ms: Int, _ block: @escaping @MainActor (GameModel) -> Void) -> UUID {
        let id = UUID()
        roundTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(ms))
            guard !Task.isCancelled, let self else { return }
            self.roundTasks[id] = nil
            block(self)
        }
        return id
    }

    /// Like `later`, but replaces any pending task with the same `tag`, so a newer bubble or hop isn't cut short.
    private func laterReplacing(_ tag: String, _ ms: Int, _ block: @escaping @MainActor (GameModel) -> Void) {
        if let old = taggedTasks[tag], let task = roundTasks.removeValue(forKey: old) { task.cancel() }
        taggedTasks[tag] = later(ms, block)
    }

    private func clearLater() {
        roundTasks.values.forEach { $0.cancel() }
        roundTasks.removeAll()
        taggedTasks.removeAll()
    }

    private func repeatEvery(_ ms: Int, _ block: @escaping @MainActor (GameModel) -> Void) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(ms))
                guard let self else { return }
                block(self)
            }
        }
    }
}

private func sign(_ value: Int) -> Int { value > 0 ? 1 : value < 0 ? -1 : 0 }

private func sign(_ value: Float) -> Int { value > 0 ? 1 : value < 0 ? -1 : 0 }
