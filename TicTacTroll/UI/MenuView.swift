import SwiftUI

/// Bubble headroom, troll and name at their design size.
private let menuTrollsHeight: CGFloat = 227
private let wideControlsWidth: CGFloat = 380

struct MenuView: View {
    let model: GameModel
    @Binding var soundOn: Bool
    @Binding var boredTrolls: Bool

    @Environment(\.wideLayout) private var wide

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if wide {
                // Side by side: title and trolls on the left, setup and Start on the right.
                HStack(spacing: 32) {
                    VStack(spacing: 10) {
                        MenuHeader()
                        MenuTrolls(state: model.state)
                    }
                    VStack(spacing: 14) { controls }
                        .frame(width: wideControlsWidth)
                        .frame(maxHeight: .infinity)
                }
                .padding(24)
                .padding(.horizontal, 8)
            } else {
                VStack(spacing: 10) {
                    MenuHeader()
                    MenuTrolls(state: model.state)
                    VStack(spacing: 14) { controls }
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 28)
            }
            SoundToggle(on: $soundOn)
                .padding(.top, 4)
                .padding(.trailing, 12)
        }
    }

    @ViewBuilder
    private var controls: some View {
        SettingsCard(model: model, boredTrolls: $boredTrolls)
        ChunkyButton(text: "Start", font: .lilita(24), tracking: 24 * 0.02, height: 60, radius: 18, shadow: 5) {
            model.start()
        }
    }
}

private struct MenuHeader: View {
    var body: some View {
        Text("A GAME OF MILD CONTEMPT")
            .font(.mono(12))
            .tracking(12 * 0.2)
            .foregroundStyle(Color.eyebrow)
            .multilineTextAlignment(.center)
            // Clears the sound toggle in the corner; large text wraps instead of running under it.
            .padding(.horizontal, 48)
        VStack(spacing: 0) {
            Text("Tic Tac").foregroundStyle(Color.cream).frame(height: 60)
            Text("Troll").foregroundStyle(Color.accent).frame(height: 60)
        }
        .font(.dirt(66))
        .shadow(color: .titleShadow, radius: 0, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tic Tac Troll")
        .accessibilityAddTraits(.isHeader)
        Text("by Nick Bradbury")
            .font(.sans(14, .normal))
            .foregroundStyle(Color.muted)
    }
}

/// The trolls take the height left over, up to their design size, so the controls always fit.
private struct MenuTrolls: View {
    let state: GameState

    var body: some View {
        GeometryReader { geometry in
            // Headroom for the speech bubble, then the troll at its 140 x 170 design proportions, then its name.
            let height = max(min(geometry.size.height - 30, menuTrollsHeight), 0)
            let name: CGFloat = 27
            let unit = max(height - name, 0) / 200
            HStack(spacing: 18) {
                MenuTroll(state: state, team: .a, key: menuA, index: 0, unit: unit)
                MenuTroll(state: state, team: .b, key: menuB, index: 1, unit: unit)
            }
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MenuTroll: View {
    let state: GameState
    let team: Team
    let key: Int
    let index: Int
    let unit: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30 * unit)
            TrollView(
                team: team,
                mood: state.excitedTroll == key ? .hop : .idle,
                gaze: state.gaze[key] ?? Gaze(),
                index: index,
                shadowHeight: 14
            )
            .frame(width: 140 * unit, height: 170 * unit)
            .overlay(alignment: .top) {
                if let text = state.bubbles[key] { SpeechBubble(text: text, fontSize: 20, lift: 34) }
            }
            Text(team.displayName)
                .font(.sans(13))
                .foregroundStyle(Color.muted)
                .padding(.top, 10)
        }
    }
}

/// All game setup in one panel: who you play, how hard the CPU is, and whether trolls get bored.
private struct SettingsCard: View {
    let model: GameModel
    @Binding var boredTrolls: Bool

    var body: some View {
        let state = model.state
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach([(Mode.pvp, "2 players"), (.cpu, "vs CPU")], id: \.1) { mode, label in
                    SelectableButton(text: label, selected: state.mode == mode, height: 48, font: .sans(15, .bold)) {
                        model.setMode(mode)
                    }
                }
            }
            // Difficulty only matters against the CPU, and sits right under that choice in a quieter style.
            if state.mode == .cpu {
                HStack(spacing: 6) {
                    ForEach([(Difficulty.easy, "Easy"), (.medium, "Medium"), (.hard, "Troll")], id: \.1) { difficulty, label in
                        SelectableButton(
                            text: label,
                            selected: state.difficulty == difficulty,
                            height: 40,
                            font: .sans(14, .medium),
                            prominent: false
                        ) { model.setDifficulty(difficulty) }
                    }
                }
                .transition(.opacity)
            }
            Toggle(isOn: $boredTrolls) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Bored trolls").font(.sans(15, .bold)).foregroundStyle(Color.ink)
                    Text("After three trolls the oldest gets bored and leaves.")
                        .font(.sans(12, .normal))
                        .foregroundStyle(Color.mutedLabel)
                }
            }
            .toggleStyle(BoredTrollsToggleStyle())
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.28)))
        .animation(.easeInOut(duration: 0.25), value: state.mode)
    }
}

private struct BoredTrollsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(on ? Color.accent : Color.outline)
                    .frame(width: 44, height: 26)
                    .overlay(alignment: .leading) {
                        Circle().fill(Color.cream).frame(width: 20, height: 20).offset(x: on ? 21 : 3)
                    }
                    .animation(.easeInOut(duration: 0.2), value: on)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

private struct SelectableButton: View {
    let text: String
    let selected: Bool
    let height: CGFloat
    let font: Font
    var prominent = true
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        let highlight = prominent ? Color.cream : Color.white.opacity(0.14)
        let textColor: Color = selected && prominent ? .onAccent : selected || prominent ? .ink : .mutedLabel
        Button(action: action) {
            Text(text)
                .font(font)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(shape.fill(selected ? highlight : .clear))
                .contentShape(shape)
                .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A round speaker button: sound waves when on, a cross when muted.
private struct SoundToggle: View {
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            Canvas { context, size in
                // Drawn on a 24-unit grid.
                let u = size.width / 24
                var speaker = Path()
                speaker.move(to: CGPoint(x: 3 * u, y: 9 * u))
                speaker.addLine(to: CGPoint(x: 8 * u, y: 9 * u))
                speaker.addLine(to: CGPoint(x: 13 * u, y: 4 * u))
                speaker.addLine(to: CGPoint(x: 13 * u, y: 20 * u))
                speaker.addLine(to: CGPoint(x: 8 * u, y: 15 * u))
                speaker.addLine(to: CGPoint(x: 3 * u, y: 15 * u))
                speaker.closeSubpath()
                context.fill(speaker, with: .color(.ink))
                var lines = Path()
                if on {
                    for radius in [4.0, 8.0] {
                        let start = radius * u / 2.squareRoot()
                        lines.move(to: CGPoint(x: 13 * u + start, y: 12 * u - start))
                        lines.addArc(
                            center: CGPoint(x: 13 * u, y: 12 * u),
                            radius: radius * u,
                            startAngle: .degrees(-45),
                            endAngle: .degrees(45),
                            clockwise: false
                        )
                    }
                } else {
                    lines.move(to: CGPoint(x: 16 * u, y: 9 * u))
                    lines.addLine(to: CGPoint(x: 22 * u, y: 15 * u))
                    lines.move(to: CGPoint(x: 22 * u, y: 9 * u))
                    lines.addLine(to: CGPoint(x: 16 * u, y: 15 * u))
                }
                context.stroke(lines, with: .color(.ink), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
            }
            .padding(12)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.scrim))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sound")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
