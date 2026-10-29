import SwiftUI

extension Team {
    var color: Color { self == .a ? .gorp : .bramble }

    var displayName: String { self == .a ? "Gorp" : "Bramble" }

    fileprivate var image: String { self == .a ? "troll_blue" : "troll_red" }

    fileprivate var eyes: [EyeSprite] { self == .a ? gorpEyes : brambleEyes }

    /// Eyelid skin, from each troll's cheeks, darkened toward the painted rim around the eyes.
    fileprivate var lid: UInt32 { self == .a ? 0x6A8BAA : 0x7A3428 }
}

/// One eye's movable iris, in troll-image pixels: the sprite, where it sits at rest, the eye opening it's clipped to,
/// and how far it can travel sideways and vertically.
private struct EyeSprite {
    let iris: String
    let left: CGFloat
    let top: CGFloat
    let socket: CGRect
    let roomX: CGFloat
    let roomY: CGFloat
}

/// A rect from its edges, like Compose's `Rect(left, top, right, bottom)`.
private func edges(_ left: CGFloat, _ top: CGFloat, _ right: CGFloat, _ bottom: CGFloat) -> CGRect {
    CGRect(x: left, y: top, width: right - left, height: bottom - top)
}

private let gorpEyes = [
    EyeSprite(iris: "troll_blue_iris0", left: 198, top: 128, socket: edges(200.5, 130.5, 227.5, 150.1), roomX: 4.7, roomY: 9.8),
    EyeSprite(iris: "troll_blue_iris1", left: 255, top: 128, socket: edges(257.2, 130.6, 290.8, 150.6), roomX: 8.0, roomY: 10.0),
]
private let brambleEyes = [
    EyeSprite(iris: "troll_red_iris0", left: 246, top: 176, socket: edges(248.5, 178.2, 293.5, 199.8), roomX: 9.7, roomY: 10.8),
    EyeSprite(iris: "troll_red_iris1", left: 346, top: 176, socket: edges(348.2, 178.0, 389.8, 200.0), roomX: 8.0, roomY: 11.0),
]

/// How much of an eye's room an iris uses at full gaze; less vertically, where the lids crowd it.
private let reachX: CGFloat = 0.75
private let reachY: CGFloat = 0.25

/// A troll's picture whose irises look toward `lookX` and `lookY` (each -1 to 1, positive is right and down), with
/// eyelids closed by `blink` (0 open, 1 shut). Fits its frame, aligned bottom-center.
struct TrollArt: View, Animatable {
    let team: Team
    var lookX: Double = 0
    var lookY: Double = 0
    var blink: Double = 0

    nonisolated var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(lookX, lookY), blink) }
        set {
            lookX = newValue.first.first
            lookY = newValue.first.second
            blink = newValue.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let base = context.resolve(Image(team.image))
            let baseSize = base.size
            let scale = min(size.width / baseSize.width, size.height / baseSize.height)
            context.translateBy(x: (size.width - baseSize.width * scale) / 2, y: size.height - baseSize.height * scale)
            context.scaleBy(x: scale, y: scale)
            context.draw(base, in: CGRect(origin: .zero, size: baseSize))
            let lid = Color(hex: team.lid)
            let lash = Color(hex: team.lid, darkenedTo: 0.35)
            for eye in team.eyes {
                var eyeContext = context
                eyeContext.clip(to: Path(ellipseIn: eye.socket))
                let iris = eyeContext.resolve(Image(eye.iris))
                let x = eye.left + lookX * eye.roomX * reachX
                let y = eye.top + lookY * eye.roomY * reachY
                eyeContext.draw(iris, in: CGRect(origin: CGPoint(x: x, y: y), size: iris.size))
                if blink > 0 {
                    // The upper lid sweeps down over the whole opening, its lashes along the leading edge.
                    let socket = eye.socket
                    let edge = socket.minY - 1 + (socket.height + 2) * blink
                    eyeContext.fill(
                        Path(CGRect(x: socket.minX, y: socket.minY - 1, width: socket.width, height: edge - socket.minY + 1)),
                        with: .linearGradient(
                            Gradient(colors: [lid, lid, lash]),
                            startPoint: CGPoint(x: 0, y: socket.minY - 1),
                            endPoint: CGPoint(x: 0, y: edge)
                        )
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}
