import SwiftUI

/// The mossy radial glow behind every screen: an ellipse 130% wide and 55% tall, centered at the top.
struct Backdrop: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.backgroundBottom))
            let rx = size.width * 1.3
            context.translateBy(x: size.width / 2, y: 0)
            context.scaleBy(x: 1, y: size.height * 0.55 / rx)
            let gradient = Gradient(stops: [
                .init(color: .backgroundTop, location: 0),
                .init(color: .backgroundBottom, location: 0.7),
            ])
            context.fill(
                Path(ellipseIn: CGRect(x: -rx, y: -rx, width: 2 * rx, height: 2 * rx)),
                with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: rx)
            )
        }
    }
}

/// "Tic Tac Troll" with "Troll" in the accent color.
struct TitleText: View {
    let font: Font
    var separator = " "

    var body: some View {
        var troll = AttributedString("Troll")
        troll.foregroundColor = .accent
        return Text(AttributedString("Tic Tac" + separator) + troll)
            .font(font)
            .foregroundStyle(Color.cream)
    }
}

/// The accent button with a hard bottom shadow that sinks when pressed.
struct ChunkyButton: View {
    let text: String
    let font: Font
    var tracking: CGFloat = 0
    let height: CGFloat
    let radius: CGFloat
    let shadow: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).font(font).tracking(tracking)
        }
        .buttonStyle(ChunkyStyle(height: height, radius: radius, shadow: shadow))
    }
}

private struct ChunkyStyle: ButtonStyle {
    let height: CGFloat
    let radius: CGFloat
    let shadow: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        let sink = configuration.isPressed ? shadow - 2 : 0
        configuration.label
            .foregroundStyle(Color.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(shape.fill(Color.accent))
            .background(shape.fill(Color.accentShadow).offset(y: shadow - sink))
            .contentShape(shape)
            .offset(y: sink)
    }
}

extension Animation {
    /// A spring specified like Compose's, by damping ratio and stiffness (with unit mass).
    static func composeSpring(damping ratio: Double, stiffness: Double) -> Animation {
        .interpolatingSpring(mass: 1, stiffness: stiffness, damping: 2 * ratio * stiffness.squareRoot())
    }
}

/// Compose's standard spring stiffnesses.
enum Stiffness {
    static let low = 200.0
    static let mediumLow = 400.0
    static let medium = 1500.0
}

/// Sleeps for `ms` milliseconds, returning false if the task was cancelled.
@discardableResult
func pause(_ ms: Int) async -> Bool {
    (try? await Task.sleep(for: .milliseconds(ms))) != nil
}
