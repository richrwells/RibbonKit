import SwiftUI

/// A single vertical tape for setting one number by dragging.
///
/// One tape, one value. It is not linked to any other ribbon. The view is only the tape and its
/// pointer; the title and the value readout belong to the caller.
///
/// Small values sit toward the top. Dragging down lowers the value, dragging up raises it.
public struct RibbonColumn: View {
    public enum TickStyle: Sendable {
        /// Integer 100%, half 70%, quarter 50%, eighth 30%, sixteenth 15% of tape width.
        case inch
        /// One full-width tick per whole number, no sub-ticks. For counts.
        case integer
    }

    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valuePerInteger: Double
    let tickStyle: TickStyle
    let pointsPerInteger: CGFloat
    let accent: Color

    /// - Parameters:
    ///   - value: The bound value, in real units (dollars, units).
    ///   - range: Allowed values, in real units.
    ///   - step: Snap increment, in real units.
    ///   - valuePerInteger: Real units per integer mark (1,000,000 for price in millions).
    ///   - tickStyle: `.inch` or `.integer`.
    ///   - pointsPerInteger: Drawn size of one integer interval, in points.
    ///   - accent: Pointer color.
    public init(value: Binding<Double>,
                range: ClosedRange<Double>,
                step: Double,
                valuePerInteger: Double = 1,
                tickStyle: TickStyle = .inch,
                pointsPerInteger: CGFloat = 108,
                accent: Color = Color(red: 0, green: 82/255, blue: 136/255)) {
        self._value = value
        self.range = range
        self.step = max(step, .ulpOfOne)
        self.valuePerInteger = valuePerInteger > 0 ? valuePerInteger : 1
        self.tickStyle = tickStyle
        self.pointsPerInteger = max(pointsPerInteger, 1)
        self.accent = accent
    }

    /// Position under the pointer, in integer units (value ÷ valuePerInteger).
    @State private var position: Double = 0
    @State private var dragStart: Double?
    @State private var motion: Task<Void, Never>?
    @State private var interacting = false

    private var lo: Double { range.lowerBound / valuePerInteger }
    private var hi: Double { range.upperBound / valuePerInteger }

    public var body: some View {
        GeometryReader { geo in
            RibbonColumnTape(position: position,
                             lo: lo, hi: hi,
                             tickStyle: tickStyle,
                             pointsPerInteger: pointsPerInteger,
                             accent: accent)
                .contentShape(Rectangle())
                .gesture(drag)
                .onTapGesture(coordinateSpace: .local) { point in
                    tap(at: point.y, height: geo.size.height)
                }
        }
        .onAppear { recenter() }
        .onChange(of: value) { _, _ in
            // Outside change (typed in the readout): recenter, never while a finger is down.
            if !interacting { recenter() }
        }
        .onChange(of: valuePerInteger) { _, _ in recenter() }
        .onChange(of: range) { _, _ in
            let clamped = clampValue(value)
            if clamped != value { value = clamped }
            recenter()
        }
        .onDisappear { motion?.cancel() }
    }

    // MARK: Gestures

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { g in
                if dragStart == nil {
                    motion?.cancel()
                    motion = nil
                    interacting = true
                    dragStart = position
                }
                let start = dragStart ?? position
                position = clampPosition(start - Double(g.translation.height / pointsPerInteger))
                publish()
            }
            .onEnded { g in
                dragStart = nil
                let speed = Double(-g.velocity.height / pointsPerInteger) // integers per second
                if abs(g.velocity.height) > 300 {
                    fling(speed: speed)
                } else {
                    snap()
                }
            }
    }

    private func tap(at y: CGFloat, height: CGFloat) {
        motion?.cancel()
        motion = nil
        let target = position + Double((y - height / 2) / pointsPerInteger)
        interacting = true
        let snapped = snapValue(target * valuePerInteger)
        value = snapped
        withAnimation(.easeOut(duration: 0.2)) { position = snapped / valuePerInteger }
        interacting = false
    }

    /// Decelerates like a scroll view, updating the binding each frame, then waits for the
    /// tape to settle (160 ms without movement) and snaps.
    private func fling(speed initial: Double) {
        motion?.cancel()
        interacting = true
        motion = Task { @MainActor in
            var speed = initial
            let frame = 1.0 / 60.0
            let decay = pow(0.998, frame * 1000) // UIScrollView normal deceleration per frame
            while abs(speed * Double(pointsPerInteger)) > 20 {
                try? await Task.sleep(nanoseconds: 16_666_667)
                if Task.isCancelled { return }
                let next = clampPosition(position + speed * frame)
                if next == position { break } // hit an end
                position = next
                publish()
                speed *= decay
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            if Task.isCancelled { return }
            snap()
        }
    }

    private func snap() {
        motion = nil
        let snapped = snapValue(position * valuePerInteger)
        if snapped != value { value = snapped }
        withAnimation(.easeOut(duration: 0.15)) { position = snapped / valuePerInteger }
        interacting = false
    }

    // MARK: Value helpers

    private func publish() {
        let v = snapValue(position * valuePerInteger)
        if v != value { value = v }
    }

    private func recenter() {
        position = clampValue(value) / valuePerInteger
    }

    private func clampValue(_ v: Double) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }

    private func clampPosition(_ p: Double) -> Double {
        min(max(p, lo), hi)
    }

    private func snapValue(_ v: Double) -> Double {
        let snapped = (v / step).rounded() * step
        // Remove binary noise (0.1 + 0.2) so readouts stay clean.
        let cleaned = (snapped * 1e6).rounded() / 1e6
        return clampValue(cleaned)
    }
}

// MARK: - Tape drawing

/// Draws the tape at a position. Animatable so snaps glide instead of jumping.
private struct RibbonColumnTape: View, Animatable {
    var position: Double
    let lo: Double
    let hi: Double
    let tickStyle: RibbonColumn.TickStyle
    let pointsPerInteger: CGFloat
    let accent: Color

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    private let fill = Color(red: 199/255, green: 230/255, blue: 237/255)   // #C7E6ED
    private let border = Color(red: 216/255, green: 218/255, blue: 221/255) // --border

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(fill)
            Canvas { context, size in
                drawTicks(in: &context, size: size)
                drawPointer(in: &context, size: size)
            }
            RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func drawTicks(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let mid = size.height / 2
        let ppi = Double(pointsPerInteger)

        // Finest level whose spacing is still at least 2 pt.
        let divisions: Int = {
            guard tickStyle == .inch else { return 1 }
            for d in [16, 8, 4, 2] where ppi / Double(d) >= 2 { return d }
            return 1
        }()
        let unit = 1.0 / Double(divisions)
        let visibleHalf = Double(mid) / ppi + unit
        let first = ((position - visibleHalf) / unit).rounded(.down)
        let last = ((position + visibleHalf) / unit).rounded(.up)
        guard last >= first, last - first < 20_000 else { return }

        let diameter = min(CGFloat(ppi) / 3, w * 0.6)
        let eps = unit / 1000

        var i = first
        while i <= last {
            let mark = i * unit
            let y = mid + CGFloat((mark - position) * ppi)
            let sixteenths = Int((i * Double(16 / divisions)).rounded()) // mark in 1/16ths
            let whole = sixteenths % 16 == 0
            let frac: CGFloat = {
                if whole { return 1 }
                if sixteenths % 8 == 0 { return 0.70 }
                if sixteenths % 4 == 0 { return 0.50 }
                if sixteenths % 2 == 0 { return 0.30 }
                return 0.15
            }()
            let inRange = mark >= lo - eps && mark <= hi + eps
            let len = w * frac
            let h: CGFloat = whole ? 2 : 1
            context.fill(Path(CGRect(x: w - len, y: y - h / 2, width: len, height: h)),
                         with: .color(Color.black.opacity(inRange ? 0.85 : 0.22)))

            if whole && inRange {
                let circle = CGRect(x: 6, y: y - diameter / 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: circle), with: .color(.white))
                context.stroke(Path(ellipseIn: circle), with: .color(.black), lineWidth: 1.5)
                let label = String(Int(mark.rounded()))
                var resolved = context.resolve(Text(label).font(.system(size: diameter * 0.8)).foregroundStyle(Color.black))
                // Multi-digit labels shrink to stay inside the circle.
                let measured = resolved.measure(in: CGSize(width: 1000, height: 1000))
                if measured.width > diameter * 0.86 {
                    let fitted = diameter * 0.8 * (diameter * 0.86 / measured.width)
                    resolved = context.resolve(Text(label).font(.system(size: fitted)).foregroundStyle(Color.black))
                }
                context.draw(resolved, at: CGPoint(x: circle.midX, y: y), anchor: .center)
            }
            i += 1
        }
    }

    private func drawPointer(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let mid = size.height / 2
        context.fill(Path(CGRect(x: 0, y: mid - 0.5, width: w, height: 1)), with: .color(accent))
        var triangle = Path()
        triangle.move(to: CGPoint(x: w - 10, y: mid))
        triangle.addLine(to: CGPoint(x: w, y: mid - 6))
        triangle.addLine(to: CGPoint(x: w, y: mid + 6))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(accent))
    }
}
