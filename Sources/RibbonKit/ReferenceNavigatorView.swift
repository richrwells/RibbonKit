import SwiftUI

public struct RefItem: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let content: String
    public init(id: String, label: String, content: String) {
        self.id = id; self.label = label; self.content = content
    }
}

public struct ReferenceNavigatorView<Content: View, Above: View, Below: View, Top: View, Bottom: View>: View {
    let items: [RefItem]
    @Binding var selected: RefItem
    var title0: String = ""
    var title1: String = ""
    var title2: String = ""
    var topContent: Top
    var bottomContent: Bottom
    var content: (RefItem) -> Content
    var above: () -> Above
    var below: () -> Below
    var accent: Color = Color(red: 0, green: 82/255, blue: 136/255)

    public init(items: [RefItem], selected: Binding<RefItem>, title0: String = "", title1: String = "", title2: String = "",
         topContent: Top, bottomContent: Bottom,
         accent: Color = Color(red: 0, green: 82/255, blue: 136/255),
         above: @escaping () -> Above,
         below: @escaping () -> Below,
         content: @escaping (RefItem) -> Content) {
        self.items = items
        self._selected = selected
        self.title0 = title0
        self.title1 = title1
        self.title2 = title2
        self.topContent = topContent
        self.bottomContent = bottomContent
        self.accent = accent
        self.above = above
        self.below = below
        self.content = content
    }

    private let ribbonColor = Color(red: 199/255, green: 230/255, blue: 237/255)
    @State private var rowHeight: CGFloat = 28
    @State private var dragStartIndex: Int?
    @State private var displayIndex: CGFloat = 0
    @State private var dragging = false
    @State private var measuredLabelWidth: CGFloat = 100
    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    public var body: some View {
        RibbonShell(title0: title0, top: topContent, bottom: bottomContent) { band, textScale, size in
            navigator(maxListWidth: size.width * 0.40, textScale: textScale)
                .frame(height: band)
                .clipped()
        }
        .onAppear {
            if selected.id.isEmpty, let first = items.first { selected = first }
        }
    }

        private func navigator(maxListWidth: CGFloat, textScale: CGFloat) -> some View {
        let listWidth = min(max(100, measuredLabelWidth + 16), maxListWidth)
        let longest = items.map(\.label).max(by: { $0.count < $1.count }) ?? ""

        return VStack(spacing: 6) {
            HStack(spacing: 18) {
                Spacer(minLength: 0)
                Text(title1).frame(width: listWidth, alignment: .center)
                Text(title2).frame(minWidth: 80, alignment: .center)
                Spacer(minLength: 0)
            }
            .font(Font.system(size: 20 * textScale, weight: .semibold))
            .foregroundStyle(Color.black)

            HStack(alignment: .center, spacing: 18) {
                Spacer(minLength: 0)
                ZStack {
                    listRibbon(width: listWidth, textScale: textScale)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accent, lineWidth: 2)
                        .frame(width: listWidth - 4, height: rowHeight)
                        .allowsHitTesting(false)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accent)
                        .offset(x: listWidth / 2 + 6)
                        .allowsHitTesting(false)
                }
                .frame(width: listWidth)

                VStack(spacing: 8) {
                    above()
                    content(selected)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent, lineWidth: 2))
                    below()
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }

            Text("0").font(.body).hidden().background(
                GeometryReader { g in Color.clear.onAppear { rowHeight = max(g.size.height, 24) } }
            )
            Text(longest).font(.body).fixedSize().hidden().background(
                GeometryReader { g in
                    Color.clear.onAppear { measuredLabelWidth = g.size.width }
                }
            )
        }
    }

    private func listRibbon(width: CGFloat, textScale: CGFloat) -> some View {
        GeometryReader { geo in
            let mid = geo.size.height / 2
            let index = items.firstIndex(where: { $0.id == selected.id }) ?? 0
            let shown = dragging ? displayIndex : CGFloat(index)
            let offset = mid - shown * rowHeight - rowHeight / 2
            VStack(spacing: 0) {
                Color.clear.frame(height: mid)
                ForEach(items) { item in
                    Text(item.label)
                        .font(Font.system(size: 17 * textScale).monospacedDigit())
                        .foregroundStyle(Color.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = item }
                }
                Color.clear.frame(height: mid)
            }
            .offset(y: offset - mid)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .background(ribbonColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 216/255, green: 218/255, blue: 221/255), lineWidth: 1))
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { g in
                        dragging = true
                        if dragStartIndex == nil {
                            dragStartIndex = items.firstIndex(where: { $0.id == selected.id }) ?? 0
                        }
                        let start = CGFloat(dragStartIndex ?? 0)
                        displayIndex = start - g.translation.height / max(rowHeight, 1)
                        let idx = min(max(0, Int(displayIndex.rounded())), items.count - 1)
                        if items[idx].id != selected.id { selected = items[idx] }
                    }
                    .onEnded { _ in
                        dragging = false
                        dragStartIndex = nil
                    }
            )
        }
        .frame(width: width)
    }
}
