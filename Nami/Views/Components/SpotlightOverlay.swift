//
//  SpotlightOverlay.swift
//  Nami
//
//  Frosted-glass spotlight coach mark with cutout effect.
//  Attach .spotlightTarget(id:) to the target view, then
//  .spotlightOverlay(id:...) to a parent to show the coach mark.
//

import SwiftUI

// MARK: - Preference Key for target frame

struct SpotlightTargetKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Target Modifier

extension View {
    /// Mark this view as a spotlight target with the given ID.
    func spotlightTarget(id: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: SpotlightTargetKey.self,
                        value: [id: geo.frame(in: .global)]
                    )
            }
        )
    }
}

// MARK: - Overlay Modifier

extension View {
    /// Show a frosted-glass spotlight overlay pointing at the target with `id`.
    /// - Parameters:
    ///   - id: The spotlight target ID to highlight
    ///   - isPresented: Binding to control visibility (set to false on dismiss)
    ///   - message: Coach mark text
    ///   - arrowDirection: Which direction the arrow points toward the target
    func spotlightOverlay(
        id: String,
        isPresented: Binding<Bool>,
        message: String,
        arrowDirection: SpotlightArrowDirection = .up
    ) -> some View {
        modifier(
            SpotlightOverlayModifier(
                targetID: id,
                isPresented: isPresented,
                message: message,
                arrowDirection: arrowDirection
            )
        )
    }
}

/// Arrow direction relative to the tooltip (points toward the target)
enum SpotlightArrowDirection {
    case up, down, left, right
}

// MARK: - Overlay Modifier Implementation

private struct SpotlightOverlayModifier: ViewModifier {
    let targetID: String
    @Binding var isPresented: Bool
    let message: String
    let arrowDirection: SpotlightArrowDirection

    @State private var targetRect: CGRect = .zero
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(SpotlightTargetKey.self) { targets in
                if let rect = targets[targetID] {
                    targetRect = rect
                }
            }
            .overlay {
                if isPresented && targetRect != .zero {
                    spotlightView
                        .opacity(opacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                opacity = 1
                            }
                        }
                }
            }
    }

    private var spotlightView: some View {
        // Expand the cutout slightly for padding
        let padding: CGFloat = 8
        let cutoutRect = targetRect.insetBy(dx: -padding, dy: -padding)
        let cutoutCornerRadius: CGFloat = min(cutoutRect.height / 2, 16)

        return ZStack {
            // Frosted glass background with cutout
            FrostedCutoutView(cutoutRect: cutoutRect, cornerRadius: cutoutCornerRadius)
                .ignoresSafeArea()

            // Tooltip with arrow
            tooltipView(cutoutRect: cutoutRect)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        }
    }

    @ViewBuilder
    private func tooltipView(cutoutRect: CGRect) -> some View {
        let arrowIcon = switch arrowDirection {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }

        VStack(spacing: 8) {
            if arrowDirection == .down {
                tooltipContent(arrowIcon: arrowIcon, arrowOnTop: false)
            } else {
                tooltipContent(arrowIcon: arrowIcon, arrowOnTop: true)
            }
        }
        .position(tooltipPosition(cutoutRect: cutoutRect))
    }

    @ViewBuilder
    private func tooltipContent(arrowIcon: String, arrowOnTop: Bool) -> some View {
        if arrowOnTop {
            messageCard
            Image(systemName: arrowIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            Image(systemName: arrowIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            messageCard
        }
    }

    private var messageCard: some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text(String(localized: "タップして閉じる"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.75))
        )
        .frame(maxWidth: 260)
    }

    private func tooltipPosition(cutoutRect: CGRect) -> CGPoint {
        let midX = cutoutRect.midX
        switch arrowDirection {
        case .up:
            // Tooltip above target, arrow points down to target
            return CGPoint(x: min(max(midX, 140), UIScreen.main.bounds.width - 140), y: cutoutRect.minY - 70)
        case .down:
            // Tooltip below target, arrow points up to target
            return CGPoint(x: min(max(midX, 140), UIScreen.main.bounds.width - 140), y: cutoutRect.maxY + 70)
        case .left:
            return CGPoint(x: cutoutRect.minX - 120, y: cutoutRect.midY)
        case .right:
            return CGPoint(x: cutoutRect.maxX + 120, y: cutoutRect.midY)
        }
    }
}

// MARK: - Frosted Glass with Cutout

private struct FrostedCutoutView: UIViewRepresentable {
    let cutoutRect: CGRect
    let cornerRadius: CGFloat

    func makeUIView(context _: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // Blur effect
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.tag = 100
        container.addSubview(blurView)

        // Semi-transparent tint
        let tintView = UIView()
        tintView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        tintView.tag = 200
        container.addSubview(tintView)

        return container
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        let bounds = UIScreen.main.bounds
        let blurView = uiView.viewWithTag(100) as? UIVisualEffectView
        let tintView = uiView.viewWithTag(200)

        blurView?.frame = bounds
        tintView?.frame = bounds

        // Create mask with cutout
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: bounds)
        let cutoutPath = UIBezierPath(roundedRect: cutoutRect, cornerRadius: cornerRadius)
        path.append(cutoutPath)
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd

        blurView?.layer.mask = maskLayer

        // Same mask for tint
        let tintMask = CAShapeLayer()
        let tintPath = UIBezierPath(rect: bounds)
        let tintCutout = UIBezierPath(roundedRect: cutoutRect, cornerRadius: cornerRadius)
        tintPath.append(tintCutout)
        tintMask.path = tintPath.cgPath
        tintMask.fillRule = .evenOdd
        tintView?.layer.mask = tintMask
    }
}
