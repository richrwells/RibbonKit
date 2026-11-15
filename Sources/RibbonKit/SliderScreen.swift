import SwiftUI

func ribbonDisplay(_ text: String, places: Int) -> String {
    guard let n = Double(text) else { return text }
    return String(format: "%.*f", places, n)
}


public struct RulerItem: Identifiable, Equatable {
    public let id: String
    public let element1: String
    public let element2: String?
    public let value: Double
    public init(id: String, element1: String, element2: String?, value: Double) {
        self.id = id; self.element1 = element1; self.element2 = element2; self.value = value
    }
}

public struct SliderScreen<Top: View, Bottom: View>: View {
    let items: [RulerItem]
    @Binding var selected: RulerItem
    let topContent: Top
    let bottomContent: Bottom
    var title0: String = ""
    var title1: String? = nil
    var title2: String? = nil
    var title3: String? = nil
    var metric: Bool = false
    var scale: CGFloat = 1.5
    var accent: Color = Color(red: 0, green: 82/255, blue: 136/255)

    public init(items: [RulerItem], selected: Binding<RulerItem>, topContent: Top, bottomContent: Bottom,
                title0: String = "", title1: String? = nil, title2: String? = nil, title3: String? = nil,
                metric: Bool = false, scale: CGFloat = 1.5,
                accent: Color = Color(red: 0, green: 82/255, blue: 136/255)) {
        self.items = items
        self._selected = selected
        self.topContent = topContent
        self.bottomContent = bottomContent
        self.title0 = title0
        self.title1 = title1
        self.title2 = title2
        self.title3 = title3
        self.metric = metric
        self.scale = scale
        self.accent = accent
    }

    private let ribbonColor = Color(red: 199/255, green: 230/255, blue: 237/255)
    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    public var body: some View {
        RibbonShell(title0: title0, top: topContent, bottom: bottomContent) { band, textScale, size in
            EndMillStyleRuler(
                items: items, selected: $selected,
                title1: title1, title2: title2, title3: title3,
                ribbonColor: ribbonColor, tapeWidth: size.width * 0.20,
                metric: metric, scale: scale, accent: accent,
                textScale: textScale, bandHeight: band
            )
        }
        .onAppear {
            if selected.id.isEmpty, let first = items.first { selected = first }
        }
    }
}

private struct EndMillStyleRuler: View {
    let items: [RulerItem]
    @Binding var selected: RulerItem
    let title1: String?
    let title2: String?
    let title3: String?
    let ribbonColor: Color
    let tapeWidth: CGFloat
    let metric: Bool
    let scale: CGFloat
    let accent: Color
    let textScale: CGFloat
    let bandHeight: CGFloat

    private var pointsPerInch: CGFloat { scale * 72 }
    @State private var dragStartValue: Double?
    @State private var displayValue: Double = 0
    @State private var displayIndex: CGFloat = 0
    @State private var draggingStrip = false
    @State private var dragStartIndex: CGFloat = 0
    @State private var rowHeight: CGFloat = 28
    @State private var measuredStrip: CGFloat = 140
    @State private var text1: CGFloat = 24
    @State private var text2: CGFloat = 40


    private func places(for texts: [String]) -> Int {
        let nums = texts.compactMap { Double($0) }.map { abs($0) }.filter { $0 > 0 }
        guard let smallest = nums.min() else { return 0 }
        if nums.allSatisfy({ $0 == $0.rounded() }) { return 0 }
        let delta = smallest * 0.001
        return min(6, max(0, Int(ceil(-log10(delta)))))
    }

    private var element1Places: Int { places(for: items.map { $0.element1 }) }
    private var element2Places: Int { places(for: items.compactMap { $0.element2 }) }

    private var col1: CGFloat { text1 + 24 }
    private var col2: CGFloat { text2 + 24 }
    private var stripWidth: CGFloat { 8 + col1 + 16 + col2 + 8 }

    private var selectedIndex: Int {
        items.firstIndex(where: { $0.id == selected.id }) ?? 0
    }

    public var body: some View {
        VStack(spacing: 4) {
            if title1 != nil || title2 != nil || title3 != nil {
                HStack(spacing: 0) {
                    Text(title1 ?? "").frame(width: tapeWidth, alignment: .center)
                    Color.clear.frame(width: 18)
                    HStack(spacing: 0) {
                        Text(title2 ?? "").lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: 8 + col1 + 8, alignment: .center)
                        Text(title3 ?? "").lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: 8 + col2 + 8, alignment: .center)
                    }
                    .frame(width: stripWidth)
                }
                .font(Font.system(size: 20 * textScale, weight: .semibold))
                .foregroundStyle(Color.black)
            }

            HStack(alignment: .center, spacing: 0) {
                TapeView(items: items, displayValue: displayValue, ribbonColor: ribbonColor,
                         tapeWidth: tapeWidth, pointsPerInch: pointsPerInch, metric: metric, accent: accent)
                    .frame(width: tapeWidth)
                    .gesture(tapeDrag)

                ZStack {
                    Color.clear
                    Image(systemName: "diamond.fill").font(Font.system(size: 8)).foregroundStyle(accent)
                }
                .frame(width: 18)
                .allowsHitTesting(false)

                ZStack {
                    ValueRibbon(items: items, element1Places: element1Places, element2Places: element2Places, col1: col1, col2: col2, selectedIndex: draggingStrip ? Int(displayIndex.rounded()) : selectedIndex, rowHeight: rowHeight, displayIndex: draggingStrip ? displayIndex : CGFloat(selectedIndex)) { item in
                        selected = item
                        displayValue = item.value
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accent, lineWidth: 2)
                        .frame(height: rowHeight)
                        .allowsHitTesting(false)
                }
                .frame(width: stripWidth)
                .contentShape(Rectangle())
                .gesture(stripDrag)
            }
            .frame(height: max(bandHeight - 36, 120))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            Text("0").font(.body).hidden().background(
                GeometryReader { g in Color.clear.onAppear { rowHeight = max(g.size.height * textScale, 24) } }
            )
        )
        .background(
            HStack(spacing: 16) {
                Text(items.map { ribbonDisplay($0.element1, places: element1Places) }.max(by: { $0.count < $1.count }) ?? "")
                    .font(.body.monospacedDigit()).fixedSize()
                    .background(GeometryReader { g in Color.clear.onAppear { text1 = max(g.size.width, text1) } })
                Text(items.map { ribbonDisplay($0.element2 ?? "", places: element2Places) }.max(by: { $0.count < $1.count }) ?? "")
                    .font(.body.monospacedDigit()).fixedSize()
                    .background(GeometryReader { g in Color.clear.onAppear { text2 = max(g.size.width, text2) } })
            }
            .hidden()
            .background(GeometryReader { g in Color.clear.onAppear { measuredStrip = g.size.width } })
        )
        .onAppear { displayValue = selected.value }
        .onChange(of: selected.id) { _, _ in
            if dragStartValue == nil { displayValue = selected.value }
        }
    }

        private var tapeDrag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { g in
                draggingStrip = false
                if dragStartValue == nil { dragStartValue = displayValue }
                let start = dragStartValue ?? displayValue
                let ppu = metric ? pointsPerInch / 10.0 : pointsPerInch
                displayValue = start - Double(g.translation.height / ppu)
                if let nearest = items.min(by: { abs($0.value - displayValue) < abs($1.value - displayValue) }) {
                    if nearest.id != selected.id { selected = nearest }
                }
            }
            .onEnded { _ in
                if let nearest = items.min(by: { abs($0.value - displayValue) < abs($1.value - displayValue) }) {
                    selected = nearest
                    displayValue = nearest.value
                }
                dragStartValue = nil
            }
    }

    private var stripDrag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { g in
                draggingStrip = true
                if dragStartValue == nil {
                    dragStartValue = displayValue
                    dragStartIndex = CGFloat(selectedIndex)
                }
                displayIndex = dragStartIndex - g.translation.height / max(rowHeight, 1)
                let idx = min(max(0, Int(displayIndex.rounded())), items.count - 1)
                let item = items[idx]
                if item.id != selected.id { selected = item }
                displayValue = item.value
            }
            .onEnded { _ in
                draggingStrip = false
                displayValue = selected.value
                displayIndex = CGFloat(selectedIndex)
                dragStartValue = nil
            }
    }
}

private struct TapeView: View {
    let items: [RulerItem]
    let displayValue: Double
    let ribbonColor: Color
    let tapeWidth: CGFloat
    let pointsPerInch: CGFloat
    let metric: Bool
    let accent: Color

    public var body: some View {
        GeometryReader { geo in
            let mid = geo.size.height / 2
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(ribbonColor)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 216/255, green: 218/255, blue: 221/255), lineWidth: 1))
                Canvas { context, size in
                    let w = size.width
                    let step = metric ? 1.0 : 1.0 / 16.0
                    let ppu = metric ? pointsPerInch / 10.0 : pointsPerInch
                    let lo = (items.first?.value ?? 0) - (metric ? 5 : 0.5)
                    let hi = (items.last?.value ?? 1) + (metric ? 5 : 0.5)
                    var mark = (lo / step).rounded(.down) * step
                    while mark <= hi + 0.0001 {
                        let y = mid + CGFloat(mark - displayValue) * ppu
                        if y > -40 && y < size.height + 40 {
                            let whole = abs(mark - mark.rounded()) < 0.001
                            let half = abs(mark * 2 - (mark * 2).rounded()) < 0.001
                            let qtr = abs(mark * 4 - (mark * 4).rounded()) < 0.001
                            let eighth = abs(mark * 8 - (mark * 8).rounded()) < 0.001
                            let mmInCm = Int(mark.rounded()) % 10
                            let metricFrac: CGFloat = {
                                if mmInCm == 0 { return 1 }
                                if mmInCm == 5 { return 0.70 }
                                if [1, 4, 6, 9].contains(mmInCm) { return 0.40 }
                                return 0.20
                            }()
                            let frac: CGFloat = metric
                                ? metricFrac
                                : (whole ? 1 : (half ? 0.70 : (qtr ? 0.50 : (eighth ? 0.30 : 0.15))))
                            let len = w * frac
                            let h: CGFloat = whole ? 2 : 1
                            let rect = CGRect(x: w - len, y: y - h/2, width: len, height: h)
                            let inRange = mark >= (items.first?.value ?? 0) - 0.001 && mark <= (items.last?.value ?? 1) + 0.001
                            context.fill(Path(rect), with: .color(Color.black.opacity(inRange ? 0.85 : 0.22)))
                            if (metric ? (Int(mark.rounded()) % 10 == 0) : whole) && mark >= 0 {
                                let label = String(format: "%.0f", metric ? mark / 10 : mark)
                                let d = (metric ? pointsPerInch : ppu) * 0.33
                                let circle = CGRect(x: 6, y: y - d/2, width: d, height: d)
                                context.fill(Path(ellipseIn: circle), with: .color(.white))
                                context.stroke(Path(ellipseIn: circle), with: .color(.black), lineWidth: 1.5)
                                let text = Text(label).font(Font.system(size: d * 0.8)).foregroundStyle(.black)
                                context.draw(text, at: CGPoint(x: circle.midX, y: y), anchor: .center)
                            }
                        }
                        mark += step
                    }
                }
                Capsule().fill(accent).frame(width: 22, height: 2).position(x: tapeWidth - 8, y: mid)
                Image(systemName: "arrowtriangle.left.fill").font(Font.system(size: 9)).foregroundStyle(accent).position(x: tapeWidth + 2, y: mid)
            }
            .clipped()
        }
    }
}

private struct ValueRibbon: View {
    let items: [RulerItem]
    let element1Places: Int
    let element2Places: Int
    let col1: CGFloat
    let col2: CGFloat
    let selectedIndex: Int
    let rowHeight: CGFloat
    var displayIndex: CGFloat = 0
    let onSelect: (RulerItem) -> Void

    public var body: some View {
        GeometryReader { geo in
            let mid = geo.size.height / 2
            let offset = mid - displayIndex * rowHeight - rowHeight / 2
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 0) {
                        Text(ribbonDisplay(item.element1, places: element1Places))
                            .frame(width: col1, alignment: .center)
                            .background(Color(red: 230/255, green: 238/255, blue: 243/255))
                        Color.clear.frame(width: 16)
                        if let e2 = item.element2 {
                            Text(ribbonDisplay(e2, places: element2Places))
                                .lineLimit(1)
                                .frame(width: col2, alignment: .center)
                        }
                    }
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.black)
                    .frame(height: rowHeight)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(item) }
                }
            }
            .offset(y: offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .background(Color(red: 230/255, green: 238/255, blue: 243/255))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 216/255, green: 218/255, blue: 221/255), lineWidth: 1))
    }
}

// MARK: - Shared shell

public struct RibbonShell<Top: View, Bottom: View, Band: View>: View {
    var title0: String
    var top: Top
    var bottom: Bottom
    var band: (_ bandHeight: CGFloat, _ textScale: CGFloat, _ size: CGSize) -> Band

    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    public var body: some View {
        GeometryReader { geo in
            let leftover = geo.size.height - topHeight - bottomHeight
            let bandHeight = min(geo.size.height * 0.70, max(geo.size.height * 0.40, leftover))
            let textScale = leftover < geo.size.height * 0.40
                ? max(0.75, leftover / (geo.size.height * 0.40))
                : 1.0
            VStack(spacing: 0) {
                if !title0.isEmpty {
                    Text(title0).font(.headline).foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity).padding(.top, 8)
                }
                ScrollView { top.frame(maxWidth: .infinity) }
                    .frame(maxHeight: geo.size.height * 0.15)
                    .background(GeometryReader { g in Color.clear.onAppear { topHeight = g.size.height } })
                Spacer(minLength: 4)
                band(bandHeight, textScale, geo.size)
                    .frame(maxHeight: bandHeight)
                    .padding(.horizontal, 12)
                Spacer(minLength: 4)
                ScrollView { bottom.frame(maxWidth: .infinity) }
                    .frame(maxHeight: geo.size.height * 0.15)
                    .background(GeometryReader { g in Color.clear.onAppear { bottomHeight = g.size.height } })
            }
            .background(Color.white)
        }
    }
}
