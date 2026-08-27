import SwiftUI

/// Full-bleed crop editor with four draggable corner handles, letting the
/// user manually correct automatically detected page edges.
struct CropView: View {
    let image: UIImage
    let initialCrop: CropRect
    /// Result of Task-1 automatic edge detection, if any arrives while this
    /// view is on screen (detection is kicked off by the caller and may
    /// finish after `onAppear`).
    var detectedCrop: CropRect?
    var isDetecting: Bool
    var onAppear: () -> Void
    var onRequestAutoDetect: () -> Void
    let onCancel: () -> Void
    let onApply: (CropRect) -> Void

    @State private var topLeft: CGPoint = .zero
    @State private var topRight: CGPoint = .zero
    @State private var bottomLeft: CGPoint = .zero
    @State private var bottomRight: CGPoint = .zero
    @State private var activeHandle: HandleID?
    @State private var magnifierLocation: CGPoint?

    private enum HandleID { case topLeft, topRight, bottomLeft, bottomRight }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let size = imageDisplaySize(in: geometry.size)
                let origin = CGPoint(x: (geometry.size.width - size.width) / 2, y: (geometry.size.height - size.height) / 2)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                    CropOverlayShape(
                        topLeft: absolute(topLeft, origin: origin, size: size),
                        topRight: absolute(topRight, origin: origin, size: size),
                        bottomLeft: absolute(bottomLeft, origin: origin, size: size),
                        bottomRight: absolute(bottomRight, origin: origin, size: size)
                    )
                    .stroke(AppColor.accentOrange, lineWidth: 2)

                    if activeHandle != nil {
                        ThirdsGridShape(
                            topLeft: absolute(topLeft, origin: origin, size: size),
                            topRight: absolute(topRight, origin: origin, size: size),
                            bottomLeft: absolute(bottomLeft, origin: origin, size: size),
                            bottomRight: absolute(bottomRight, origin: origin, size: size)
                        )
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        .transition(.opacity)
                    }

                    handle(.topLeft, $topLeft, origin: origin, size: size)
                    handle(.topRight, $topRight, origin: origin, size: size)
                    handle(.bottomLeft, $bottomLeft, origin: origin, size: size)
                    handle(.bottomRight, $bottomRight, origin: origin, size: size)

                    if let magnifierLocation {
                        MagnifierView(image: image, focusPoint: magnifierLocation, imageOrigin: origin, imageSize: size)
                            .position(magnifierPosition(for: magnifierLocation, in: geometry.size))
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: activeHandle)
                .onAppear {
                    setCorners(initialCrop, animated: false)
                    onAppear()
                }
                .onChange(of: detectedCrop) { newValue in
                    // Only auto-apply when the user hasn't started with a
                    // real crop already (still at the full-frame default);
                    // a manual on-demand re-run always applies.
                    guard let newValue else { return }
                    if initialCrop == .fullFrame {
                        setCorners(newValue, animated: true)
                    }
                }
            }
            .background(Color.black)

            if isDetecting {
                HStack(spacing: 8) {
                    ProgressView().tint(AppColor.accentAmber)
                    Text(L("crop.detecting"))
                        .font(AppTypography.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            HStack(spacing: 20) {
                iconButton(system: "wand.and.stars", label: L("crop.auto")) {
                    onRequestAutoDetect()
                }
                iconButton(system: "arrow.up.left.and.arrow.down.right", label: L("crop.resetFull")) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        setCorners(.fullFrame, animated: true)
                    }
                }
                Spacer()
                Button(L("action.cancel")) { onCancel() }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 120)
                Button(L("action.apply")) {
                    onApply(CropRect(
                        topLeft: topLeft, topRight: topRight,
                        bottomLeft: bottomLeft, bottomRight: bottomRight
                    ))
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 120)
            }
            .padding(AppMetrics.standardPadding)
        }
        .background(AppColor.backgroundBlack.ignoresSafeArea())
    }

    private func setCorners(_ crop: CropRect, animated: Bool) {
        let apply = {
            topLeft = crop.topLeft
            topRight = crop.topRight
            bottomLeft = crop.bottomLeft
            bottomRight = crop.bottomRight
        }
        if animated {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { apply() }
        } else {
            apply()
        }
    }

    private func imageDisplaySize(in bounds: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let boundsAspect = bounds.width / bounds.height
        if imageAspect > boundsAspect {
            return CGSize(width: bounds.width, height: bounds.width / imageAspect)
        } else {
            return CGSize(width: bounds.height * imageAspect, height: bounds.height)
        }
    }

    private func absolute(_ normalized: CGPoint, origin: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: origin.x + normalized.x * size.width, y: origin.y + normalized.y * size.height)
    }

    private func magnifierPosition(for point: CGPoint, in bounds: CGSize) -> CGPoint {
        // Float the magnifier above the finger, but keep it clear of the
        // top edge when the corner being dragged is near the top.
        let liftedY = point.y > 140 ? point.y - 110 : point.y + 110
        return CGPoint(x: min(max(point.x, 70), bounds.width - 70), y: liftedY)
    }

    private func handle(_ id: HandleID, _ point: Binding<CGPoint>, origin: CGPoint, size: CGSize) -> some View {
        let absPoint = absolute(point.wrappedValue, origin: origin, size: size)
        let isActive = activeHandle == id
        return ZStack {
            Circle()
                .fill(AppColor.accentAmber)
                .frame(width: isActive ? 32 : 24, height: isActive ? 32 : 24)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.4), radius: isActive ? 4 : 2)
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .position(absPoint)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    activeHandle = id
                    let newX = min(max((value.location.x - origin.x) / size.width, 0), 1)
                    let newY = min(max((value.location.y - origin.y) / size.height, 0), 1)
                    point.wrappedValue = CGPoint(x: newX, y: newY)
                    magnifierLocation = value.location
                }
                .onEnded { _ in
                    activeHandle = nil
                    magnifierLocation = nil
                }
        )
    }

    private func iconButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.title3)
                Text(label)
                    .font(AppTypography.caption())
            }
            .foregroundStyle(AppColor.accentOrange)
        }
        .accessibilityLabel(label)
    }
}

private struct CropOverlayShape: Shape {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
        return path
    }
}

/// Rule-of-thirds guide lines drawn inside the (possibly skewed)
/// quadrilateral, shown only while a handle is actively being dragged.
private struct ThirdsGridShape: Shape {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        for t: CGFloat in [1.0 / 3, 2.0 / 3] {
            path.move(to: lerp(topLeft, topRight, t))
            path.addLine(to: lerp(bottomLeft, bottomRight, t))
            path.move(to: lerp(topLeft, bottomLeft, t))
            path.addLine(to: lerp(topRight, bottomRight, t))
        }
        return path
    }
}

/// Small floating loupe showing a zoomed-in view of the image under the
/// finger while a corner handle is being dragged, so the user can see
/// exactly where the corner will land without a fingertip blocking it.
private struct MagnifierView: View {
    let image: UIImage
    let focusPoint: CGPoint
    let imageOrigin: CGPoint
    let imageSize: CGSize

    private let diameter: CGFloat = 90
    private let zoom: CGFloat = 2.5

    var body: some View {
        let relativeX = (focusPoint.x - imageOrigin.x) / max(imageSize.width, 1)
        let relativeY = (focusPoint.y - imageOrigin.y) / max(imageSize.height, 1)

        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize.width * zoom, height: imageSize.height * zoom)
            .offset(
                x: diameter / 2 - relativeX * imageSize.width * zoom,
                y: diameter / 2 - relativeY * imageSize.height * zoom
            )
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppColor.accentAmber, lineWidth: 2))
            .shadow(color: .black.opacity(0.5), radius: 6)
        }
}
