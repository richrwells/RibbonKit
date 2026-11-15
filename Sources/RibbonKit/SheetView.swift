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

    private func columnWidth(_ index: Int, screen: CGFloat) -> CGFloat {
        let header = titles.indices.contains(index) ? titles[index] : ""
        let sub = subtitles.indices.contains(index) ? subtitles[index] : ""
        let cells = index == 0
            ? rows.map { $0.list }
            : rows.map { $0.values.indices.contains(index - 1) ? $0.values[index - 1] : "" }
        let longest = ([header, sub] + cells).map { CGFloat($0.count) }.max() ?? 1
        let natural = max(72, longest * 9 + 20)
        let cap = index == 0 ? screen * 0.40 : screen * 0.60
        return min(natural, cap)
    }

    private func widths(for screen: CGFloat) -> [CGFloat] {
        (0..<columnCount).map { columnWidth($0, screen: screen) }
    }

    private func sheet(width: CGFloat, textScale: CGFloat) -> some View {
        let w = widths(for: width)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                header(0, width: w[0]).frame(width: w[0])
                SheetLinkedScroll(axis: .horizontal, role: .follower) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(1..<columnCount, id: \.self) { i in
                            header(i, width: w[i]).frame(width: w[i])
                        }
                    }
                }
                .frame(height: headerHeight)
            }
            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    dataColumn(0, width: w[0]).frame(width: w[0])
                    SheetLinkedScroll(axis: .horizontal, role: .leader) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(1..<columnCount, id: \.self) { i in
                                dataColumn(i, width: w[i]).frame(width: w[i])
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: width)
    }

    private var headerHeight: CGFloat { (showSubtitles ? 72 : 36) }

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


import UIKit

private enum SheetScrollRole { case leader, follower }

private struct SheetLinkedScroll<Content: View>: UIViewRepresentable {
    var axis: Axis
    var role: SheetScrollRole
    var content: Content

    init(axis: Axis, role: SheetScrollRole, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.role = role
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = role == .leader
        scroll.showsVerticalScrollIndicator = false
        scroll.bounces = true
        scroll.backgroundColor = .clear
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor)
        ])
        context.coordinator.host = host
        if role == .leader {
            SheetScrollLink.shared.leader = scroll
        } else {
            SheetScrollLink.shared.follower = scroll
            scroll.isScrollEnabled = false
        }
        SheetScrollLink.shared.bind()
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.host?.rootView = content
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var host: UIHostingController<Content>?
    }
}

private final class SheetScrollLink {
    static let shared = SheetScrollLink()
    weak var leader: UIScrollView?
    weak var follower: UIScrollView?
    var token: NSKeyValueObservation?

    func bind() {
        guard let leader else { return }
        token = leader.observe(\.contentOffset, options: [.new]) { [weak self] view, _ in
            self?.follower?.contentOffset.x = view.contentOffset.x
        }
    }
}
