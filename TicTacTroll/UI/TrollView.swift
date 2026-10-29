import SwiftUI

enum Mood { case idle, hop, shrug, yawn }

/// A startle away from a troll that just landed nearby: `away` is the side to lean (-1, 0 or 1), and a new `key`
/// retriggers it.
struct Flinch: Equatable {
    let away: Int
    let key: [Int]
}

/// How long a troll takes to drop onto its crate; the landing thunk and haptic wait this long to hit with it.
let landingMs = 150

private let dropHeight: CGFloat = 70
private let yawnMs = 1300

/// A troll that drops in when it appears, breathes, blinks, looks and tilts its head toward `gaze`, and hops, shrugs
/// or yawns per `mood`. `index` staggers the animations so trolls don't move in sync; the shadow fades when not
/// `grounded`; `flinch` makes it startle away from a new neighbor.
struct TrollView: View {
    let team: Team
    let mood: Mood
    let gaze: Gaze
    let index: Int
    let shadowHeight: CGFloat
    var grounded = true
    var flinch: Flinch?

    // Landing: falls from above onto the crate, then squashes on impact and springs back.
    @State private var drop = 0.0
    @State private var squash = 0.0
    // Body motion per mood.
    @State private var bodyY = 0.0
    @State private var rotation = 0.0
    @State private var stretch = 0.0
    @State private var lids = 0.0
    @State private var jolt = 0.0
    @State private var breathe = 1.0
    @State private var head: Double
    @State private var eyeX: Double
    @State private var eyeY: Double

    init(team: Team, mood: Mood, gaze: Gaze, index: Int, shadowHeight: CGFloat, grounded: Bool = true, flinch: Flinch? = nil) {
        self.team = team
        self.mood = mood
        self.gaze = gaze
        self.index = index
        self.shadowHeight = shadowHeight
        self.grounded = grounded
        self.flinch = flinch
        _head = State(initialValue: Double(gaze.dx))
        _eyeX = State(initialValue: Double(gaze.dx))
        _eyeY = State(initialValue: Double(gaze.dy))
    }

    var body: some View {
        let away = Double(flinch?.away ?? 0)
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.black)
                    .frame(width: geometry.size.width * 0.76, height: shadowHeight)
                    .blur(radius: 3)
                    .opacity(0.35 * drop)
                    .animation(.easeInOut(duration: 0.2)) { $0.opacity(grounded ? 1 : 0) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: shadowHeight / 3)
            }
            // Decorative: the board cell or the name under a menu troll describes it.
            TrollArt(team: team, lookX: eyeX, lookY: eyeY, blink: lids)
                // Squashes wide on impact, stretches tall in a yawn.
                .scaleEffect(x: 1 + 0.12 * squash, y: 1 - 0.16 * squash, anchor: .bottom)
                .scaleEffect(x: 1 - 0.4 * stretch, y: 1 + stretch, anchor: .bottom)
                .scaleEffect(x: 1, y: breathe, anchor: .bottom)
                .rotationEffect(.degrees(rotation + head * 8 + away * 7 * jolt), anchor: .bottom)
                .offset(x: head * 3 + away * 3 * jolt, y: bodyY - (1 - drop) * dropHeight - 5 * jolt)
        }
        .accessibilityHidden(true)
        .task { await land() }
        .task { await breatheForever() }
        .task(id: mood) { await moveBody() }
        .task(id: mood) { await blink() }
        .task(id: flinch) { await startle() }
        .onChange(of: gaze) {
            withAnimation(.composeSpring(damping: 0.5, stiffness: Stiffness.low)) { head = Double(gaze.dx) }
            // Eyes dart ahead of the slower head turn.
            withAnimation(.composeSpring(damping: 0.8, stiffness: Stiffness.medium)) {
                eyeX = Double(gaze.dx)
                eyeY = Double(gaze.dy)
            }
        }
    }

    private func land() async {
        withAnimation(.easeIn(duration: Double(landingMs) / 1000)) { drop = 1 }
        guard await pause(landingMs) else { return }
        squash = 1
        guard await pause(16) else { return }
        withAnimation(.composeSpring(damping: 0.35, stiffness: Stiffness.medium)) { squash = 0 }
    }

    private func breatheForever() async {
        guard await pause(index * 370 % 2000) else { return }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { breathe = 1.03 }
    }

    private func moveBody() async {
        bodyY = 0
        rotation = 0
        stretch = 0
        switch mood {
        case .hop:
            guard await pause(index % 3 * 100) else { return }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.3)) { bodyY = -12 }
                guard await pause(300) else { return }
                withAnimation(.easeInOut(duration: 0.3)) { bodyY = 0 }
                guard await pause(300) else { return }
            }
        case .shrug:
            for _ in 0..<3 {
                for (y, angle, ms) in [(-7.0, -3.0, 200), (-4, 3, 150), (0, 0, 150)] {
                    withAnimation(.easeInOut(duration: Double(ms) / 1000)) {
                        bodyY = y
                        rotation = angle
                    }
                    guard await pause(ms) else { return }
                }
            }
        case .yawn:
            // A slow stretch up and back, then a slump.
            withAnimation(.easeOut(duration: 0.55)) {
                rotation = -2.5
                stretch = 0.07
            }
            guard await pause(800) else { return }
            withAnimation(.easeInOut(duration: Double(yawnMs - 800) / 1000)) { rotation = 0 }
            withAnimation(.easeInOut(duration: 0.25)) { stretch = -0.04 }
            guard await pause(250) else { return }
            withAnimation(.easeInOut(duration: 0.25)) { stretch = 0 }
        case .idle:
            break
        }
    }

    /// Quick random blinks, sometimes doubled; sleepy while yawning; and one slow, disapproving blink during a draw's
    /// stare.
    private func blink() async {
        lids = 0
        switch mood {
        case .shrug:
            guard await pause(700) else { return }
            withAnimation(.easeInOut(duration: 0.26)) { lids = 1 }
            guard await pause(260 + 180) else { return }
            withAnimation(.easeInOut(duration: 0.32)) { lids = 0 }
        case .yawn:
            withAnimation(.easeInOut(duration: 0.4)) { lids = 0.65 }
            guard await pause(400 + 500) else { return }
            withAnimation(.easeInOut(duration: 0.3)) { lids = 0 }
        default:
            while !Task.isCancelled {
                guard await pause(Int.random(in: 2200..<6000)) else { return }
                for _ in 0..<(Float.random(in: 0..<1) < 0.15 ? 2 : 1) {
                    withAnimation(.easeInOut(duration: 0.07)) { lids = 1 }
                    guard await pause(70) else { return }
                    withAnimation(.easeInOut(duration: 0.11)) { lids = 0 }
                    guard await pause(110) else { return }
                }
            }
        }
    }

    /// A quick jolt timed to a new neighbor hitting its crate.
    private func startle() async {
        guard flinch != nil, await pause(landingMs) else { return }
        withAnimation(.easeOut(duration: 0.09)) { jolt = 1 }
        guard await pause(90) else { return }
        withAnimation(.composeSpring(damping: 0.5, stiffness: Stiffness.mediumLow)) { jolt = 0 }
    }
}

/// A speech bubble whose bottom sits `lift` above the top of the view it's placed over.
struct SpeechBubble: View {
    let text: String
    let fontSize: CGFloat
    let lift: CGFloat

    @State private var scale = 0.4

    var body: some View {
        Text(text)
            .font(.lilita(fontSize))
            .foregroundStyle(Color.bubbleInk)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.bubbleCream))
            .background(Capsule().fill(Color.black.opacity(0.25)).offset(y: 3))
            .scaleEffect(scale)
            .opacity(min(max((scale - 0.4) / 0.6, 0), 1))
            .offset(y: -lift)
            // Chatter isn't read aloud; it would interrupt VoiceOver every few seconds.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.composeSpring(damping: 0.5, stiffness: Stiffness.medium)) { scale = 1 }
            }
    }
}
