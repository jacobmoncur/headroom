import SwiftUI
import HeadroomCore

struct ExploreView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var sort = Sort.size
    @State private var scope = Scope.all

    enum Sort: String, CaseIterable { case size = "Biggest first", recent = "Newest first" }
    enum Scope: String, CaseIterable { case all = "All large files", recent = "Added recently", cloud = "Stored in iCloud", installers = "Old downloads", generated = "Temporary app files" }

    private var allItems: [ScannedItem] { model.current?.largeItems ?? [] }
    private var items: [ScannedItem] {
        allItems.filter { item in
            let matchesSearch = search.isEmpty || item.url.lastPathComponent.localizedCaseInsensitiveContains(search) || item.url.path.localizedCaseInsensitiveContains(search)
            guard matchesSearch else { return false }
            let path = item.url.path.lowercased(), ext = item.url.pathExtension.lowercased()
            switch scope {
            case .all: return true
            case .recent: return Date.now.timeIntervalSince(item.modifiedAt) < 30 * 86_400
            case .cloud: return item.cloudBacked == true
            case .installers: return ["dmg", "pkg", "zip", "xip"].contains(ext)
            case .generated: return path.contains("/deriveddata/") || path.contains("/library/caches/") || path.contains("/node_modules/")
            }
        }.sorted { sort == .size ? $0.allocatedSize > $1.allocatedSize : $0.modifiedAt > $1.modifiedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(eyebrow: "Look closer when you want to", title: "What’s using space",
                       subtitle: "Browse the largest files Headroom found. Nothing on this screen changes or deletes a file.") {
                HStack {
                    TextField("Search by file name", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
                    Picker("Sort", selection: $sort) { ForEach(Sort.allCases, id: \.self) { Text($0.rawValue) } }.frame(width: 145)
                }
            }

            HStack(spacing: 10) {
                ForEach(Scope.allCases, id: \.self) { value in
                    Button(value.rawValue) { scope = value }
                        .buttonStyle(.bordered).tint(scope == value ? Palette.mint : .secondary)
                }
                Spacer()
                Text("\(items.count) large file\(items.count == 1 ? "" : "s") using \(StorageFormatting.bytes(items.reduce(0) { $0 + $1.allocatedSize }))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }

            if items.isEmpty {
                Panel { InlineEmptyState(icon: "doc.text.magnifyingglass", title: search.isEmpty ? "Nothing in this group" : "No matching files", message: "Try another group, clear your search, or check your storage again.") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(items) {
                    TableColumn("File") { item in
                        HStack(spacing: 9) { Image(systemName: icon(for: item)).foregroundStyle(Palette.mint); VStack(alignment: .leading, spacing: 1) { Text(item.url.lastPathComponent).lineLimit(1); Text(sourceLabel(for: item)).font(.caption2).foregroundStyle(.tertiary) } }.help(item.url.path)
                            .contextMenu { Button("Open a preview") { model.quickLook(item) }; Button("Show in Finder") { model.reveal(item) }; Divider(); Button("Never suggest this file") { model.protect(item) } }
                    }
                    TableColumn("Kind") { item in Text(kindLabel(for: item)).foregroundStyle(.secondary) }.width(110)
                    TableColumn("Last changed") { item in Text(item.modifiedAt, format: .relative(presentation: .named)).foregroundStyle(.secondary) }.width(120)
                    TableColumn("Space used") { item in Text(StorageFormatting.bytes(item.allocatedSize)).monospacedDigit() }.width(110)
                    TableColumn("Actions") { item in HStack(spacing: 10) { Button { model.quickLook(item) } label: { Image(systemName: "eye") }.buttonStyle(.plain).help("Open a preview").accessibilityLabel("Preview \(item.url.lastPathComponent)"); Button { model.reveal(item) } label: { Image(systemName: "folder") }.buttonStyle(.plain).help("Show in Finder").accessibilityLabel("Show \(item.url.lastPathComponent) in Finder") } }.width(66)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.45)))
            }
        }
        .padding(30)
    }

    private func icon(for item: ScannedItem) -> String {
        if item.cloudBacked == true { return "icloud" }
        switch item.fileType { case "Video": return "film"; case "Images": return "photo"; case "Archives & installers": return "shippingbox"; case "Audio": return "waveform"; case "Source code": return "chevron.left.forwardslash.chevron.right"; default: return "doc" }
    }

    private func sourceLabel(for item: ScannedItem) -> String {
        if let application = item.application, application != "Other" { return application }
        return "In \(item.category)"
    }

    private func kindLabel(for item: ScannedItem) -> String {
        if let fileType = item.fileType, fileType != "Other" { return fileType }
        return item.category
    }
}
