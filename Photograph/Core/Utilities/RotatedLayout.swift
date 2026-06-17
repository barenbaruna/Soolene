import SwiftUI

struct RotatedLayout: Layout {
    var angle: Angle

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        let size = view.sizeThatFits(.unspecified)
        
        let radians = angle.radians
        let cosA = abs(cos(radians))
        let sinA = abs(sin(radians))
        
        let newWidth = size.width * cosA + size.height * sinA
        let newHeight = size.width * sinA + size.height * cosA
        
        return CGSize(width: newWidth, height: newHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let view = subviews.first else { return }
        view.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}
