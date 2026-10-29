import SwiftUI

extension EnvironmentValues {
    /// True when the window is wide enough that the screens lay out side by side.
    @Entry var wideLayout = false
}

/// The space each arrangement is designed for: a phone in portrait, and a side-by-side landscape layout.
private let tallDesign = CGSize(width: 412, height: 860)
private let wideDesign = CGSize(width: 860, height: 520)

/// Wider than this many times its height, a window gets the side-by-side layout.
private let wideAspect: CGFloat = 1.25

/// Scales near 1 are left alone, so phones keep the exact design size.
private let snapRange: ClosedRange<CGFloat> = 0.95...1.15
private let scaleRange: ClosedRange<CGFloat> = 0.6...2.4

/// Scales `content` so the design fits the window: bigger on iPads, smaller on small phones or in a narrow window.
/// The content is laid out at the unscaled size and then scaled, so touch targets stay aligned with what's drawn.
struct FitToWindow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let wide = size.width > size.height * wideAspect
            let design = wide ? wideDesign : tallDesign
            let fit = min(size.width / design.width, size.height / design.height)
            let scale = snapRange.contains(fit) ? 1 : min(max(fit, scaleRange.lowerBound), scaleRange.upperBound)
            content()
                .environment(\.wideLayout, wide)
                .frame(width: size.width / scale, height: size.height / scale)
                .scaleEffect(scale)
                .frame(width: size.width, height: size.height)
        }
    }
}
