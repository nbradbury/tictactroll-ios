import SwiftUI

/// Room around the crate for its drop shadows, which a Canvas would otherwise clip.
private let shadowRoom: CGFloat = 30

/// A wooden crate (planks, diagonal brace, frame and shadows), outlined in `glow` when it's part of a winning line.
struct Crate: View {
    var glow: Color?

    var body: some View {
        let radius: CGFloat = 4
        Canvas { context, canvasSize in
            context.translateBy(x: shadowRoom, y: shadowRoom)
            let size = CGSize(width: canvasSize.width - 2 * shadowRoom, height: canvasSize.height - 2 * shadowRoom)
            let rect = CGRect(origin: .zero, size: size)
            let border: CGFloat = 6

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 6))
                layer.fill(
                    Path(roundedRect: rect.offsetBy(dx: 0, dy: 12), cornerRadius: radius),
                    with: .color(.black.opacity(0.4))
                )
            }
            context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 5), cornerRadius: radius), with: .color(.crateShadow))
            context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(.crateBorder))

            let inner = size.width - 2 * border
            let face = CGRect(x: border, y: border, width: inner, height: size.height - 2 * border)
            var planks = context
            planks.clip(to: Path(face))
            planks.fill(Path(face), with: .color(.cratePlank))
            // A 2pt seam every 33pt, measured up from the bottom.
            let plank: CGFloat = 31
            let seam: CGFloat = 2
            var y = size.height - border - plank - seam
            while y > border - seam {
                planks.fill(Path(CGRect(x: 0, y: y, width: size.width, height: seam)), with: .color(.crateSeam))
                y -= plank + seam
            }
            var brace = Path()
            brace.move(to: CGPoint(x: border, y: border))
            brace.addLine(to: CGPoint(x: size.width - border, y: size.height - border))
            planks.stroke(brace, with: .color(.crateBrace), lineWidth: inner * 0.1 * 1.414)
            planks.fill(
                Path(CGRect(x: border, y: border, width: inner, height: 3)),
                with: .color(Color(hex: 0xFFE6BE, alpha: 0x14 / 255.0))
            )
            planks.stroke(
                Path(CGRect(x: border, y: border, width: inner, height: inner)),
                with: .color(.black.opacity(0.25)),
                lineWidth: 1
            )
        }
        .padding(-shadowRoom)
        .overlay {
            RoundedRectangle(cornerRadius: radius + 0.5)
                .stroke(glow ?? .clear, lineWidth: 3)
                .padding(-0.5)
                .animation(.easeInOut(duration: 0.3), value: glow)
        }
        .allowsHitTesting(false)
    }
}
