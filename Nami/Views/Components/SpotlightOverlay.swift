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

/// Arrow direction: which way the arrow points (toward the target)
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
        let padding: CGFloat = 8
        let cutoutRect = targetRect.insetBy(dx: -padding, dy: -padding)
        let cutoutCornerRadius: CGFloat = min(cutoutRect.height / 2, 16)

        return ZStack {
            // Frosted glass background with cutout
            FrostedCutoutView(cutoutRect: cutoutRect, cornerRadius: cutoutCornerRadius)
                .ignoresSafeArea()

            // Tooltip positioned relative to cutout
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
        let screenWidth = UIScreen.main.bounds.width
        let tooltipMaxWidth: CGFloat = 260
        let spacing: CGFloat = 12

        // Clamp horizontal center to keep tooltip on screen
        let clampedX = min(max(cutoutRect.midX, tooltipMaxWidth / 2 + 16), screenWidth - tooltipMaxWidth / 2 - 16)

        VStack(spacing: 4) {
            switch arrowDirection {
            case .up:
                // Arrow points UP toward target → tooltip is BELOW target
                arrowTriangle(direction: .up)
                messageCard
            case .down:
                // Arrow points DOWN toward target → tooltip is ABOVE target
                messageCard
                arrowTriangle(direction: .down)
            case .left:
                HStack(spacing: 4) {
                    arrowTriangle(direction: .left)
                    messageCard
                }
            case .right:
                HStack(spacing: 4) {
                    messageCard
                    arrowTriangle(direction: .right)
                }
            }
        }
        .position(tooltipCenter(cutoutRect: cutoutRect, spacing: spacing, clampedX: clampedX))
    }

    /// Triangle arrow pointing toward the target
    private func arrowTriangle(direction: SpotlightArrowDirection) -> some View {
        Triangle()
            .fill(.black.opacity(0.75))
            .frame(width: 16, height: 8)
            .rotationEffect(triangleRotation(for: direction))
    }

    private func triangleRotation(for direction: SpotlightArrowDirection) -> Angle {
        switch direction {
        case .up: return .zero // pointing up
        case .down: return .degrees(180)
        case .left: return .degrees(-90)
        case .right: return .degrees(90)
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

    private func tooltipCenter(cutoutRect: CGRect, spacing: CGFloat, clampedX: CGFloat) -> CGPoint {
        switch arrowDirection {
        case .up:
            // Tooltip below the target
            return CGPoint(x: clampedX, y: cutoutRect.maxY + spacing + 40)
        case .down:
            // Tooltip above the target
            return CGPoint(x: clampedX, y: cutoutRect.minY - spacing - 40)
        case .left:
            return CGPoint(x: cutoutRect.minX - 120, y: cutoutRect.midY)
        case .right:
            return CGPoint(x: cutoutRect.maxX + 120, y: cutoutRect.midY)
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
