import Testing
@testable import TicTacTroll

/// Never triggers medium's 20% "random move" roll.
private struct Focused: RandomNumberGenerator {
    mutating func next() -> UInt64 { .max }
}

private func board(_ s: String) -> Board {
    s.map { $0 == "A" ? .a : $0 == "B" ? .b : nil }
}

private func position(_ b: String, _ history: Int...) -> Position {
    Position(board: board(b), history: history)
}

/// Plays `moves` from an empty board under rolling rules, A first.
private func rolling(_ moves: Int...) -> Position {
    moves.enumerated().reduce(Position()) { pos, move in pos.play(move.element, move.offset % 2 == 0 ? .a : .b, .rolling) }
}

struct GameLogicTests {
    private var focused = Focused()

    @Test func judgeFindsEveryLine() {
        for line in lines {
            let b: Board = (0..<cells).map { line.contains($0) ? .b : nil }
            #expect(judge(b) == GameResult(winner: .b, line: line))
        }
    }

    @Test func judgeReportsDrawOnFullBoardWithoutALine() {
        #expect(judge(board("ABAABBBAA")) == GameResult(winner: nil, line: []))
    }

    @Test func judgeReturnsNilForGameInProgress() {
        #expect(judge(board("AB.......")) == nil)
    }

    @Test mutating func mediumTakesTheWinOverBlocking() {
        // B can win at 5, A threatens at 2.
        #expect(cpuPick(Position(board: board("AA.BB....")), .medium, using: &focused) == 5)
    }

    @Test mutating func mediumBlocksAnImmediateThreat() {
        #expect(cpuPick(Position(board: board("AA..B....")), .medium, using: &focused) == 2)
    }

    @Test func rollingFourthTrollMakesTheOldestLeave() {
        // A: 0, 1, 8. B: 3, 4, 6. A's fourth at 5 doesn't win, so 0 leaves.
        let before = rolling(0, 3, 1, 4, 8, 6)
        #expect(before.leavingNext(.a, .rolling) == 0)
        let after = before.play(5, .a, .rolling)
        #expect(after.board == board(".A.BBAB.A"))
        #expect(after.history == [3, 1, 4, 8, 6, 5])
        #expect(judge(after.board) == nil)
    }

    @Test func rollingLineCompletedWithTheLeavingTrollWinsAndItStays() {
        // A's fourth at 2 completes 0-1-2 with the oldest troll at 0: the win comes first.
        let after = rolling(0, 3, 1, 4, 8, 6).play(2, .a, .rolling)
        #expect(after.board[0] == .a)
        #expect(judge(after.board) == GameResult(winner: .a, line: [0, 1, 2]))
        #expect(winningMove(rolling(0, 3, 1, 4, 8, 6), .a, .rolling) == 2)
    }

    @Test func classicNeverMakesATrollLeave() {
        #expect(rolling(0, 3, 1, 4, 8, 6).leavingNext(.a, .classic) == nil)
    }

    @Test(arguments: [Difficulty.medium, .hard])
    mutating func cpuTakesARollingWinThatUsesItsOwnOldestTroll(difficulty: Difficulty) {
        // B: 3 (oldest), 4, 8. B at 5 completes 3-4-5 with its oldest troll, which beats blocking A at 2.
        let pos = position("AA.BB.A.B", 3, 0, 4, 1, 8, 6)
        #expect(cpuPick(pos, difficulty, using: &focused, rules: .rolling) == 5)
    }

    @Test(arguments: [Difficulty.medium, .hard])
    mutating func cpuBlocksARollingThreatThatUsesTheOpponentsOldestTroll(difficulty: Difficulty) {
        // A: 3 (oldest), 4, 8. A at 5 would complete 3-4-5 with its oldest troll, so B must block there.
        let pos = position("B..AA.B.A", 3, 0, 4, 6, 8)
        #expect(cpuPick(pos, difficulty, using: &focused, rules: .rolling) == 5)
    }

    @Test func hardNeverLoses() {
        playAll(emptyBoard, .a)
        playAll(emptyBoard, .b)
    }

    /// Explores every human (A) move sequence against the hard CPU (B).
    private func playAll(_ board: Board, _ turn: Team) {
        if let result = judge(board) {
            #expect(result.winner != .a, "CPU lost on \(board)")
            return
        }
        if turn == .b {
            var next = board
            next[cpuPick(Position(board: board), .hard)] = .b
            playAll(next, .a)
        } else {
            for i in board.indices where board[i] == nil {
                var next = board
                next[i] = .a
                playAll(next, .b)
            }
        }
    }
}
