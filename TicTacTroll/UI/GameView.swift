import SwiftUI

private let cell: CGFloat = 108
private let step: CGFloat = 118 // cell + gap
private let boardSize: CGFloat = 344
private let topBarButtonBand: CGFloat = 96
private let widePanelWidth: CGFloat = 380
private let piecePadding = EdgeInsets(top: 4, leading: 10, bottom: 8, trailing: 10)
private let popSwellMs = 140
private let popBurstMs = 380
private let popDroplets = 8
private let popAfterLandingMs = 250
private let ghostHoldMs = 200

struct GameView: View {
    let model: GameModel

    @Environment(\.wideLayout) private var wide

    var body: some View {
        let state = model.state
        ZStack(alignment: wide ? .bottomLeading : .bottom) {
            if wide {
                // Side by side: scores and status on the left, the board on the right.
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) { header(state) }
                        .frame(width: widePanelWidth)
                    BoardView(model: model)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 0) {
                    header(state)
                    BoardView(model: model).padding(.top, 26)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if state.showSheet, let result = state.result {
                // Side by side, the sheet rises under the scores so the board stays in view.
                ResultSheet(winner: result.winner, onMenu: model.toMenu, onRematch: model.rematch)
                    .frame(width: wide ? widePanelWidth + 48 : nil)
                    .transition(.asymmetric(insertion: .offset(y: 30).combined(with: .opacity), removal: .identity))
            }
        }
        .animation(.timingCurve(0.2, 1.2, 0.4, 1, duration: 0.4), value: state.showSheet)
    }

    @ViewBuilder
    private func header(_ state: GameState) -> some View {
        TopBar(onMenu: model.toMenu, onRestart: model.restart)
        ScoreChips(state: state).padding(.top, 14)
        GameStatus(state: state).padding(.top, 22)
    }
}

private struct GameStatus: View {
    let state: GameState

    var body: some View {
        Text(statusText(state))
            .font(.sans(17))
            .foregroundStyle(Color.ink)
            .multilineTextAlignment(.center)
            .frame(minHeight: 28)
            // Read aloud whenever it changes, so VoiceOver users hear every move, including the CPU's.
            .onChange(of: announcement) {
                AccessibilityNotification.Announcement(announcement).post()
            }
    }

    private var announcement: String {
        [lastMoveAnnouncement(state), statusText(state)].compactMap { $0 }.joined(separator: " ")
    }
}

private func statusText(_ state: GameState) -> String {
    if let result = state.result {
        return result.winner.map { "\($0.displayName) wins." } ?? "Draw."
    }
    return state.isCpuTurn ? "Bramble is thinking… barely." : "\(state.turn.displayName)'s move"
}

/// "Bramble played row 1, column 3." plus, under rolling rules, which troll left. Nil before the first move.
private func lastMoveAnnouncement(_ state: GameState) -> String? {
    guard let last = state.history.last, let mover = state.board[last] else { return nil }
    var text = "\(mover.displayName) played row \(last / columns + 1), column \(last % columns + 1)."
    if let departed = state.departed {
        text += " \(mover.displayName)’s oldest troll left row \(departed / columns + 1), column \(departed % columns + 1)."
    }
    return text
}

private struct TopBar: View {
    let onMenu: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            // Reserve a band for the buttons on each side so the centered title can't run into them.
            TitleText(font: .dirt(21))
                .lineLimit(1)
                .minimumScaleFactor(12 / 21)
                .padding(.horizontal, topBarButtonBand + 8)
            HStack {
                Button(action: onMenu) {
                    Text("‹")
                        .font(.sans(22, .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.scrim))
                }
                .accessibilityLabel("Back to menu")
                Spacer()
                Button(action: onRestart) {
                    Text("Restart")
                        .font(.sans(13))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(9 / 13)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Capsule().fill(Color.scrim))
                        .frame(maxWidth: topBarButtonBand)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ScoreChips: View {
    let state: GameState

    var body: some View {
        let playing = state.result == nil
        HStack(spacing: 10) {
            ScoreChip(team: .a, name: "Gorp", score: state.scores.a, active: playing && state.turn == .a)
            VStack(spacing: 0) {
                Text("DRAW").font(.mono(11)).foregroundStyle(Color.drawLabel)
                Text("\(state.scores.draws)").font(.lilita(20)).foregroundStyle(Color.muted)
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            ScoreChip(
                team: .b,
                name: state.mode == .cpu ? "Bramble (CPU)" : "Bramble",
                score: state.scores.b,
                active: playing && state.turn == .b
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ScoreChip: View {
    let team: Team
    let name: String
    let score: Int
    let active: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        let mirrored = team == .b
        HStack(spacing: 10) {
            if !mirrored { avatar }
            VStack(alignment: mirrored ? .trailing : .leading, spacing: 0) {
                Text(name)
                    .font(.sans(12))
                    .foregroundStyle(Color.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(9 / 12)
                Text("\(score)").font(.lilita(26)).foregroundStyle(Color.ink)
            }
            if mirrored { avatar }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: mirrored ? .trailing : .leading)
        .background(shape.fill(Color.scrim))
        .overlay(shape.strokeBorder(active ? team.color : .clear, lineWidth: 2))
        .animation(.easeInOut(duration: 0.25), value: active)
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        TrollArt(team: team).frame(width: 34, height: 40)
    }
}

private struct BoardView: View {
    let model: GameModel

    var body: some View {
        let state = model.state
        ZStack(alignment: .topLeading) {
            // The dirt strip the losing trolls topple onto.
            LinearGradient(colors: [.dirtTop, .dirtBottom], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .top) { Color.grass.frame(height: 3) }
                .frame(width: boardSize + 80, height: 120)
                .offset(x: -40, y: boardSize - 6)
            // All crates sit in one layer under the trolls, so a falling loser's raised cell can't carry its crate
            // over a neighbor's speech bubble.
            ForEach(0..<cells, id: \.self) { i in
                let won = state.result.flatMap { result in result.line.contains(i) ? result.winner?.color : nil }
                Crate(glow: won)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(i % columns) * step, y: CGFloat(i / columns) * step)
            }
            ForEach(0..<cells, id: \.self) { i in
                let fallen = state.board[i].map(state.isFallen) ?? false
                CellView(model: model, index: i)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(i % columns) * step, y: CGFloat(i / columns) * step)
                    // A losing troll falls in front of the trolls below it.
                    .zIndex(fallen ? 10 + Double(2 - i / columns) : 1)
            }
        }
        .frame(width: boardSize, height: boardSize, alignment: .topLeading)
    }
}

private struct CellView: View {
    let model: GameModel
    let index: Int

    var body: some View {
        let state = model.state
        let team = state.board[index]
        let clickable = team == nil && state.acceptsMove
        Button { model.play(index) } label: {
            ZStack {
                if let team {
                    PieceView(state: state, team: team, index: index) { model.popFallen(index) }
                } else if state.departed == index, let mover = state.history.last.flatMap({ state.board[$0] }) {
                    // Keyed on the move, so each new departure swells and bursts once.
                    DepartingTroll(team: mover).id(state.history)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(CellButtonStyle(ghost: clickable ? state.turn : nil))
        .disabled(!clickable)
        .accessibilityLabel(cellDescription(state, team))
        .accessibilityHint(clickable ? "Place \(state.turn.displayName)" : "")
    }

    /// "Row 1, column 2: Gorp, leaves next", 1-based for VoiceOver.
    private func cellDescription(_ state: GameState, _ team: Team?) -> String {
        let occupant = team.map { state.leavingNext == index ? "\($0.displayName), leaves next" : $0.displayName } ?? "empty"
        return "Row \(index / columns + 1), column \(index % columns + 1): \(occupant)"
    }
}

/// While a cell is held, shows a ghost of the troll about to land; sliding off the crate cancels the move.
private struct CellButtonStyle: ButtonStyle {
    let ghost: Team?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay { Ghost(team: ghost, pressed: configuration.isPressed) }
    }
}

/// Appears only once the press has lasted `ghostHoldMs`, so a quick tap never shows it.
private struct Ghost: View {
    let team: Team?
    let pressed: Bool

    @State private var held = false

    var body: some View {
        Group {
            if held, let team {
                TrollArt(team: team).padding(piecePadding).opacity(0.35)
            }
        }
        .allowsHitTesting(false)
        .task(id: pressed) {
            held = false
            if pressed, await pause(ghostHoldMs) { held = true }
        }
    }
}

/// A bored troll leaving: it swells like a bubble and vanishes as the burst goes off.
private struct DepartingTroll: View {
    let team: Team

    @State private var swell = 0.0
    @State private var gone = false

    var body: some View {
        ZStack {
            TrollArt(team: team)
                .padding(piecePadding)
                .scaleEffect(1 + 0.25 * swell)
                .opacity(gone ? 0 : 1)
            PopBurst(color: team.color)
        }
        .onAppear {
            withAnimation(.easeIn(duration: Double(popSwellMs) / 1000)) { swell = 1 }
            withAnimation(.linear(duration: 0.09).delay(Double(popSwellMs - 40) / 1000)) { gone = true }
        }
    }
}

/// The bubble burst where a troll was: a ring snapping outward and a spray of droplets in `color`, fading.
private struct PopBurst: View {
    let color: Color
    var offset: CGSize = .zero

    @State private var progress = 0.0

    var body: some View {
        GeometryReader { geometry in
            let reach = min(geometry.size.width, geometry.size.height)
            BurstShape(color: color, reach: reach, progress: progress)
                .frame(width: reach * 2, height: reach * 2)
                .position(
                    x: geometry.size.width / 2 + offset.width,
                    y: geometry.size.height * 0.55 + offset.height
                )
        }
        .allowsHitTesting(false)
        .task {
            guard await pause(popSwellMs - 30) else { return }
            // Compose's LinearOutSlowInEasing.
            withAnimation(.timingCurve(0, 0, 0.2, 1, duration: Double(popBurstMs) / 1000)) { progress = 1 }
        }
    }
}

private struct BurstShape: View, Animatable {
    let color: Color
    let reach: CGFloat
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let p = progress
            guard p > 0, p < 1 else { return }
            let fade = 1 - p
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let ring = reach * (0.26 + 0.28 * p)
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: 2 * ring, height: 2 * ring)),
                with: .color(Color.cream.opacity(0.85 * fade)),
                lineWidth: max(6 * fade, 1)
            )
            let distance = reach * (0.28 + 0.3 * p)
            let radius = 4.5 * (1 - 0.5 * p)
            for k in 0..<popDroplets {
                let angle = 2 * Double.pi * Double(k) / Double(popDroplets) + 0.4
                let x = center.x + cos(angle) * distance
                let y = center.y + sin(angle) * distance
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius)),
                    with: .color(color.opacity(fade))
                )
            }
        }
    }
}

/// A troll on the board, which topples off its crate onto the dirt when its team loses, then pops.
private struct PieceView: View {
    let state: GameState
    let team: Team
    let index: Int
    let onLanded: () -> Void

    @State private var fall = 0.0
    @State private var pop = 0.0

    var body: some View {
        let row = index / columns
        let fallen = state.isFallen(team)
        let popped = state.popped.contains(index)
        let direction = fallDirection(row: row, col: index % columns)
        let drop = Double(2 - row) * step + 44
        ZStack {
            TrollView(
                team: team,
                mood: moodOf(state),
                gaze: state.gaze[index] ?? Gaze(),
                index: index,
                shadowHeight: 10,
                grounded: !fallen,
                flinch: flinchOf(state)
            )
            // Under rolling rules, the troll about to get bored is dimmed as a warning.
            .animation(.easeInOut(duration: 0.25)) { $0.opacity(state.leavingNext == index ? 0.5 : 1) }
            .modifier(FallAndPop(fall: fall, pop: pop, direction: direction, drop: drop))
            .padding(piecePadding)

            if popped {
                // Centered on the troll lying in the dirt: half its height to the side of its feet, level with them.
                PopBurst(color: team.color, offset: CGSize(width: Double(direction) * 48, height: drop + 41))
            }
            if let text = state.bubbles[index] {
                // Follows a fallen troll down: sideways toward where its head lies, and down into the dirt.
                Color.clear
                    .overlay(alignment: .top) { SpeechBubble(text: text, fontSize: 18, lift: 22) }
                    .offset(x: fall * Double(direction) * 40, y: fall * (drop + 50))
            }
        }
        .task(id: fallen) {
            if fallen {
                guard await pause(index % 5 * 120 + 250) else { return }
                withAnimation(.timingCurve(0.55, 0, 0.75, 1.2, duration: 0.8)) { fall = 1 }
                guard await pause(800 + popAfterLandingMs) else { return }
                onLanded()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) { fall = 0 }
            }
        }
        .task(id: popped) {
            if popped {
                withAnimation(.easeIn(duration: Double(popSwellMs) / 1000)) { pop = 1 }
            } else {
                pop = 0
            }
        }
    }

    /// The three trolls in the winning line hop; during a draw's stare, everyone shrugs; the bored troll yawns.
    private func moodOf(_ state: GameState) -> Mood {
        if let result = state.result, result.winner == team, result.line.contains(index) { return .hop }
        if state.result?.isDraw == true && state.stare { return .shrug }
        if state.yawning == index { return .yawn }
        return .idle
    }

    /// Trolls next to the one that just landed startle away from it.
    private func flinchOf(_ state: GameState) -> Flinch? {
        guard let last = state.history.last, last != index,
              abs(last / columns - index / columns) <= 1, abs(last % columns - index % columns) <= 1
        else { return nil }
        let away = (index % columns - last % columns).signum()
        return Flinch(away: away, key: state.history)
    }
}

/// Which way a losing troll topples: off the nearest side, alternating by row in the middle column.
private func fallDirection(row: Int, col: Int) -> Int {
    switch col {
    case 0: -1
    case columns - 1: 1
    default: row % 2 == 1 ? 1 : -1
    }
}

/// Topples a troll about its feet into the dirt, then swells it like a bubble, fading out over the last stretch as
/// the burst goes off.
private struct FallAndPop: ViewModifier, Animatable {
    var fall: Double
    var pop: Double
    let direction: Int
    let drop: Double

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fall, pop) }
        set {
            fall = newValue.first
            pop = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.25 * pop, anchor: .bottom)
            .rotationEffect(.degrees(fall * Double(direction) * 90), anchor: .bottom)
            .offset(y: fall * drop)
            .opacity(1 - min(max((pop - 0.7) / 0.3, 0), 1))
    }
}

private struct ResultSheet: View {
    let winner: Team?
    let onMenu: () -> Void
    let onRematch: () -> Void

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
        VStack(alignment: .leading, spacing: 6) {
            Text(winner.map { "\($0.displayName) wins." } ?? "Draw.")
                .font(.dirt(34))
                .foregroundStyle(Color.cream)
            Text(winner.map { "\($0.other.displayName)’s trolls hit the dirt." } ?? "Nobody’s impressed. Meh.")
                .font(.sans(15, .normal))
                .foregroundStyle(Color.muted)
                .padding(.bottom, 12)
            GeometryReader { geometry in
                HStack(spacing: 10) {
                    Button(action: onMenu) {
                        Text("Menu")
                            .font(.sans(15, .bold))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.outline, lineWidth: 1.5))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .frame(width: (geometry.size.width - 10) / 2.4)
                    ChunkyButton(text: "Rematch", font: .lilita(22), height: 54, radius: 16, shadow: 4, action: onRematch)
                }
            }
            .frame(height: 54)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The background runs on past the bottom edge, under the home indicator.
        .background(alignment: .top) {
            shape
                .fill(Color.sheetBackground)
                .padding(.bottom, -100)
                .shadow(color: .black.opacity(0.4), radius: 15, y: -10)
        }
        // Swallow taps so they don't reach the board underneath.
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}
