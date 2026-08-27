import SwiftUI

/// Full-bleed crop editor with four draggable corner handles, letting the
/// user manually correct automatically detected page edges.
struct CropView: View {
    let image: UIImage
    let initialCrop: CropRect
    let onCancel: () -> Void
    let onApply: (CropRect) -> Void

    @State private var topLeft: CGPoint = .zero
    @State private var topRight: CGPoint = .zero
    @State private var bottomLeft: CGPoint = .zero
    @State private var bottomRight: CGPoint = .zero
    @State private var frameSize: CGSize = .zero

    var body: some View {
        VStack {
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

                    handle($topLeft, origin: origin, size: size)
                    handle($topRight, origin: origin, size: size)
                    handle($bottomLeft, origin: origin, size: size)
                    handle($bottomRight, origin: origin, size: size)
                }
                .onAppear {
                    frameSize = size
                    topLeft = initialCrop.topLeft
                    topRight = initialCrop.topRight
                    bottomLeft = initialCrop.bottomLeft
                    bottomRight = initialCrop.bottomRight
                }
            }
            .background(Color.black)

            HStack(spacing: 16) {
                Button(L("action.cancel")) { onCancel() }
                    .buttonStyle(SecondaryButtonStyle())
                Button(L("action.apply")) {
                    onApply(CropRect(
                        topLeft: topLeft, topRight: topRight,
                        bottomLeft: bottomLeft, bottomRight: bottomRight
                    ))
                } .buttonStyle(PrimaryButtonStyle())
            }
            .padding(AppMetrics.standardPadding)
        }
        .background(AppColor.backgroundBlack.ignoresSafeArea())
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

    private func handle(_ point: Binding<CGPoint>, origin: CGPoint, size: CGSize) -> some View {
        let absPoint = absolute(point.wrappedValue, origin: origin, size: size)
        return Circle()
            .fill(AppColor.accentAmber)
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .position(absPoint)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newX = min(max((value.location.x - origin.x) / size.width, 0), 1)
                        let newY = min(max((value.location.y - origin.y) / size.height, 0), 1)
                        point.wrappedValue = CGPoint(x: newX, y: newY)
                    }
            )
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
