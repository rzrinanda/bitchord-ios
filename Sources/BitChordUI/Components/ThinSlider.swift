import SwiftUI

/// ThinSlider: High-performance Apple Music-style hairline capsule scrubber.
/// - Resting state: 7pt hairline capsule height
/// - Dragging state: Expands smoothly to 12pt with spring animation
/// - Hit box: 34pt vertical tap target (.contentShape(Rectangle()))
/// - Pure SwiftUI DragGesture(minimumDistance: 0) to guarantee instant response and zero missed touches
/// - Decouples local drag state from audio engine time updates while finger is down, eliminating jitter and snapping back
public struct ThinSlider: View {
    public let value: Double
    public let maximum: Double
    public var label: String
    public var trackColor: Color
    public var progressColor: Color
    public var onEditingChanged: (Double) -> Void
    public var onDraggingChanged: ((Bool) -> Void)?
    public var onDragValueChanged: ((Double) -> Void)?

    @State private var dragging: Bool = false
    @State private var dragValue: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        value: Double,
        maximum: Double,
        label: String = "Playback position",
        trackColor: Color = Color.white.opacity(0.24),
        progressColor: Color = Color.white.opacity(0.92),
        onEditingChanged: @escaping (Double) -> Void,
        onDraggingChanged: ((Bool) -> Void)? = nil,
        onDragValueChanged: ((Double) -> Void)? = nil
    ) {
        self.value = value
        self.maximum = maximum
        self.label = label
        self.trackColor = trackColor
        self.progressColor = progressColor
        self.onEditingChanged = onEditingChanged
        self.onDraggingChanged = onDraggingChanged
        self.onDragValueChanged = onDragValueChanged
    }

    private var current: Double {
        dragging ? (dragValue ?? value) : value
    }

    private var fraction: Double {
        guard maximum > 0 else { return 0 }
        return min(max(current / maximum, 0), 1)
    }

    public var body: some View {
        GeometryReader { geo in
            let height: CGFloat = dragging ? 12 : 7
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(trackColor)
                
                // Progress Track
                if fraction > 0 {
                    Capsule()
                        .fill(progressColor)
                        .clipShape(Capsule())
                        .frame(width: max(height, geo.size.width * fraction))
                }
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging {
                            onDraggingChanged?(true)
                        }
                        dragging = true
                        let f = min(max(g.location.x / max(1, geo.size.width), 0), 1)
                        let newDrag = f * maximum
                        dragValue = newDrag
                        onDragValueChanged?(newDrag)
                    }
                    .onEnded { _ in
                        let finalValue = dragValue ?? value
                        onEditingChanged(finalValue)
                        dragging = false
                        dragValue = nil
                        onDraggingChanged?(false)
                    }
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: dragging)
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onEditingChanged(min(maximum, current + 1))
            case .decrement: onEditingChanged(max(0, current - 5))
            @unknown default: break
            }
        }
    }
}
