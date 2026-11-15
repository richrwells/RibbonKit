import SwiftUI

public struct SheetRow: Identifiable, Equatable {
    public let id: String
    public let list: String
    public let values: [String]

    public init(id: String, list: String, values: [String]) {
        self.id = id
        self.list = list
        self.values = Array(values.prefix(4))
    }
}

public struct SheetView<Top: View, Bottom: View>: View {
    let rows: [SheetRow]
    var title0: String = ""
    var titles: [String] = []
    var subtitles: [String] = []
    let topContent: Top
    let bottomContent: Bottom
    var accent: Color = Color(red: 0, green: 82/255, blue: 136/255)

    private let border = Color(red: 216/255, green: 218/255, blue: 221/255)
    private let stripe = Color(red: 244/255, green: 245/255, blue: 246/255)
    @State private var hOffset: CGFloat = 0

    public init(rows: [SheetRow], title0: String = "", titles: [String] = [], subtitles: [String] = [],
                accent: Color = Color(red: 0, green: 82/255, blue: 136/255),
                @ViewBuilder topContent: () -> Top, @ViewBuilder bottomContent: () -> Bottom) {
        self.rows = rows
        self.title0 = title0
        self.titles = Array(titles.prefix(5))
        self.subtitles = Array(subtitles.prefix(5))
        self.topContent = topContent()
        self.bottomContent = bottomContent()
        self.accent = accent
    }

    public var body: some View {
        RibbonShell(title0: title0, top: topContent, bottom: bottomContent) { band, textScale, size in
            sheet(width: size.width, textScale: textScale)
                .frame(height: band)
                .clipped()
        }
    }

    private var columnCount: Int { min(5, max(titles.count, rows.map { $0.values.count + 1 }.max() ?? 1)) }
    private var showSubtitles: Bool { subtitles.contains { !$0.isEmpty } }

    private func columnWidth(_ index: Int, maxWidth: CGFloat) -> CGFloat {
        let header = titles.indices.contains(index) ? titles[index] : ""
        let sub = subtitles.indices.contains(index) ? subtitles[index] : ""
        let cells = index == 0
            ? rows.map { $0.list }
            : rows.map { $0.values.indices.contains(index - 1) ? $0.values[index - 1] : "" }
        let longest = ([header, sub] + cells).map { $0.count }.max() ?? 1
        let natural = max(72, CGFloat(longest) * 8 + 16)
        return index == 0 ? min(natural, maxWidth) : natural
    }

    private func sheet(width: CGFloat, textScale: CGFloat) -> some View {
        let listW = columnWidth(0, maxWidth: width * 0.40)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                header(0, width: listW).frame(width: listW)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(1..<columnCount, id: \.self) { header($0, width: columnWidth($0, maxWidth: width)) }
                }
                .offset(x: hOffset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    dataColumn(0, width: listW).frame(width: listW)
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(1..<columnCount, id: \.self) { dataColumn($0, width: columnWidth($0, maxWidth: width)) }
                        }
                        .background(GeometryReader { g in
                            Color.clear.preference(key: SheetOffsetKey.self, value: g.frame(in: .named("sheetH")).minX)
                        })
                    }
                    .coordinateSpace(name: "sheetH")
                }
            }
        }
        .onPreferenceChange(SheetOffsetKey.self) { hOffset = $0 }
        .frame(maxWidth: width)
    }

    private func header(_ index: Int, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            if titles.indices.contains(index), !titles[index].isEmpty {
                cell(titles[index], width: width, weight: .semibold, fill: stripe)
            }
            if showSubtitles {
                cell(subtitles.indices.contains(index) ? subtitles[index] : "", width: width, weight: .regular, fill: stripe)
            }
        }
    }

    private func dataColumn(_ index: Int, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                let text = index == 0 ? row.list : (row.values.indices.contains(index - 1) ? row.values[index - 1] : "")
                cell(text, width: width, weight: .regular, fill: .white)
            }
        }
    }

    private func cell(_ text: String, width: CGFloat, weight: Font.Weight, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: weight))
            .foregroundStyle(Color.black)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .frame(width: width, height: 36)
            .background(fill)
            .overlay(Rectangle().stroke(border, lineWidth: 0.5))
    }
}

private struct SheetOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
