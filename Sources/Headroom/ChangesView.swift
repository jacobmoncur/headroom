import Charts
import SwiftUI
import HeadroomCore

struct ChangesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var range = Range.week

    enum Range: String, CaseIterable {
        case day = "Today", week = "7 days", month = "30 days"
        var seconds: TimeInterval { self == .day ? 86_400 : (self == .week ? 604_800 : 2_592_000) }
    }

    private var visibleSnapshots: [StorageSnapshot] {
        model.snapshots.filter { Date.now.timeIntervalSince($0.capturedAt) <= range.seconds }
    }
    private var recovered: Int64 {
        model.actions.filter { Date.now.timeIntervalSince($0.performedAt) <= range.seconds }.reduce(0) { $0 + $1.recoveredBytes }
    }

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "Understand the difference",
                    title: "Recent changes",
                    subtitle: "See whether your free space went up or down—and which folders explain most of the change."
                ) {
                    Picker("Time period", selection: $range) {
                        ForEach(Range.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                changeSummary
                historyPanel
                largestChanges

                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(eyebrow: "Current picture", title: "Where your storage is going")
                    Text("These groups show what Headroom can currently see, not every byte on your Mac.")
                        .font(.callout).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                        breakdown(title: "Apps and activities", subtitle: "What likely created the files", groups: model.current?.applications ?? [])
                        breakdown(title: "Kinds of files", subtitle: "Videos, photos, documents, and more", groups: model.current?.fileTypes ?? [])
                        breakdown(title: "Folders", subtitle: "Where the files live", groups: model.current?.groups ?? [])
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
    }

    private var changeSummary: some View {
        Panel {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: summaryIcon)
                    .font(.system(size: 34))
                    .foregroundStyle(summaryColor)
                    .frame(width: 54, height: 54)
                    .background(summaryColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(summaryTitle).font(.title2.weight(.semibold))
                    Text(summaryDetail).font(.body).foregroundStyle(.secondary)
                }
                Spacer()
                if recovered > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(StorageFormatting.bytes(recovered)).font(.title2.weight(.semibold)).foregroundStyle(Palette.mint)
                        Text("freed with Headroom").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var historyPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your free space over time").font(.headline)
                        Text("Higher is better. Each dot is a completed storage check.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(visibleSnapshots.count) check\(visibleSnapshots.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if visibleSnapshots.count < 2 {
                    InlineEmptyState(icon: "chart.line.uptrend.xyaxis", title: "One more check will show a trend", message: "Headroom saved today’s free space. Check again later to see what changed.")
                    HStack { Spacer(); Button("Check again") { model.scan() }.disabled(model.isScanning); Spacer() }
                } else {
                    Chart(visibleSnapshots) { snapshot in
                        LineMark(x: .value("Date", snapshot.capturedAt), y: .value("Free space", snapshot.freeSpace))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Palette.mint)
                            .lineStyle(.init(lineWidth: 2.5))
                        AreaMark(x: .value("Date", snapshot.capturedAt), y: .value("Free space", snapshot.freeSpace))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Palette.mint.opacity(0.26), .clear], startPoint: .top, endPoint: .bottom))
                        PointMark(x: .value("Date", snapshot.capturedAt), y: .value("Free space", snapshot.freeSpace))
                            .foregroundStyle(Palette.mint)
                    }
                    .chartYScale(domain: yDomain)
                    .chartYAxis { AxisMarks(format: .byteCount(style: .file)) }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                    .frame(height: 230)
                    .accessibilityLabel("Free space over time")
                }
            }
        }
    }

    private var largestChanges: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("What changed the most").font(.headline)
                        Text("“Used more” means the group grew. “Used less” means it freed space.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.anomalies.isEmpty {
                        StatusPill(text: "\(model.anomalies.count) unusual change\(model.anomalies.count == 1 ? "" : "s")", color: Palette.amber)
                    }
                }
                if model.deltas.isEmpty {
                    InlineEmptyState(icon: "arrow.left.arrow.right", title: "No comparison yet", message: "Headroom needs two completed checks before it can explain what grew or got smaller.")
                } else {
                    ForEach(model.deltas) { delta in
                        HStack(spacing: 12) {
                            Image(systemName: delta.bytes >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(delta.bytes >= 0 ? Palette.amber : Palette.mint)
                                .frame(width: 30, height: 30)
                                .background((delta.bytes >= 0 ? Palette.amber : Palette.mint).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(delta.name).font(.headline)
                                Text(delta.bytes >= 0 ? "Used more space" : "Used less space")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(StorageFormatting.bytes(abs(delta.bytes)))
                                .font(.headline).monospacedDigit()
                                .foregroundStyle(delta.bytes >= 0 ? Palette.amber : Palette.mint)
                        }
                        .accessibilityElement(children: .combine)
                        if delta.id != model.deltas.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var netChange: Int64? {
        guard let first = visibleSnapshots.first, let last = visibleSnapshots.last, first.id != last.id else { return nil }
        return last.freeSpace - first.freeSpace
    }

    private var summaryTitle: String {
        guard let netChange else { return "Headroom is ready to notice changes" }
        if netChange > 0 { return "You gained \(StorageFormatting.bytes(netChange)) of free space" }
        if netChange < 0 { return "You used \(StorageFormatting.bytes(abs(netChange))) of free space" }
        return "Your free space stayed about the same"
    }

    private var summaryDetail: String {
        guard netChange != nil else { return "Check again later and Headroom will explain what changed." }
        return "This compares the first and latest storage checks in the selected time period."
    }

    private var summaryIcon: String {
        guard let netChange else { return "clock" }
        return netChange >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var summaryColor: Color {
        guard let netChange else { return .secondary }
        return netChange >= 0 ? Palette.mint : Palette.amber
    }

    private var yDomain: ClosedRange<Int64> {
        let values = visibleSnapshots.map(\.freeSpace)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let padding = max(5_000_000_000, (high - low) / 4)
        return max(0, low - padding)...(high + padding)
    }

    private func breakdown(title: String, subtitle: String, groups: [StorageGroup]) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                if groups.isEmpty {
                    InlineEmptyState(icon: "square.stack.3d.up.slash", title: "Still learning", message: "A fresh check will add this breakdown.")
                } else {
                    ForEach(groups.prefix(5)) { group in
                        HStack(spacing: 10) {
                            Image(systemName: group.friendlyIcon).foregroundStyle(Palette.mint).frame(width: 20).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(group.name).lineLimit(1)
                                    Spacer()
                                    Text(StorageFormatting.bytes(group.bytes)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                }
                                GeometryReader { proxy in
                                    Capsule().fill(.secondary.opacity(0.12))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Palette.mint.opacity(0.75)).frame(width: proxy.size.width * relativeWidth(group, in: groups))
                                        }
                                }
                                .frame(height: 5)
                                .accessibilityHidden(true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func relativeWidth(_ group: StorageGroup, in groups: [StorageGroup]) -> Double {
        guard let largest = groups.first?.bytes, largest > 0 else { return 0 }
        return min(1, Double(group.bytes) / Double(largest))
    }
}
