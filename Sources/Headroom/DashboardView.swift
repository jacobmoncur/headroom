import SwiftUI
import HeadroomCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    private var health: StorageHealth { model.health }
    private var capacity: Int64 { model.current?.capacity ?? 0 }
    private var usedSpace: Int64 { max(0, capacity - health.freeSpace) }
    private var storageGroups: [StorageGroup] {
        let fileTypes = model.current?.fileTypes ?? []
        let fileTypeTotal = fileTypes.reduce(Int64(0)) { $0 + $1.bytes }
        let otherDominates = fileTypes.first.map { $0.name == "Other" && fileTypeTotal > 0 && Double($0.bytes) / Double(fileTypeTotal) > 0.45 } ?? false
        return fileTypes.isEmpty || otherDominates ? (model.current?.groups ?? []) : fileTypes
    }

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "Your Mac today",
                    title: "Your storage",
                    subtitle: "See how much room you have, what is taking up space, and the safest thing to do next."
                ) {
                    VStack(alignment: .trailing, spacing: 7) {
                        Button(action: model.scan) {
                            Label(model.isScanning ? "Checking…" : "Check again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isScanning)
                        if let date = model.lastScanDate {
                            Text("Last checked \(date, format: .relative(presentation: .named))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                storageHero
                storageBreakdown

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { changedPanel; nextActions }
                    VStack(spacing: 16) { changedPanel; nextActions }
                }
            }
            .padding(30)
            .frame(maxWidth: 1160)
            .frame(maxWidth: .infinity)
        }
    }

    private var storageHero: some View {
        Panel {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 22) {
                    Image(systemName: health.isHealthy ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(health.isHealthy ? Palette.mint : Palette.coral)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(health.isHealthy ? "Your Mac has room to breathe" : "Your Mac is running low on room")
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                        Text(heroExplanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(StorageFormatting.bytes(health.freeSpace))
                            .font(.system(size: 31, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("free of \(StorageFormatting.bytes(capacity))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                storageBar

                HStack(spacing: 24) {
                    StorageLegend(color: .secondary.opacity(0.55), title: "Used", value: StorageFormatting.bytes(usedSpace))
                    StorageLegend(color: Palette.mint, title: "Available to use", value: StorageFormatting.bytes(health.spendable))
                    StorageLegend(color: Color.blue.opacity(0.75), title: "Safety cushion", value: StorageFormatting.bytes(min(health.freeSpace, health.reserve)))
                    Spacer()
                    if !model.recommendations.isEmpty {
                        Button("See ways to make space") { model.destination = .actions }
                            .buttonStyle(.borderedProminent)
                    }
                }

                if let days = health.runwayDays {
                    Label("At your recent pace, you may reach your safety cushion in about \(days) days.", systemImage: "calendar.badge.clock")
                        .font(.callout)
                        .foregroundStyle(days < 14 ? Palette.amber : .secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var storageBar: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.55))
                    .frame(width: totalWidth * fraction(usedSpace))
                Rectangle()
                    .fill(Palette.mint)
                    .frame(width: totalWidth * fraction(health.spendable))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.blue.opacity(0.75))
                    .frame(width: totalWidth * fraction(min(health.freeSpace, health.reserve)))
            }
        }
        .frame(height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storage use")
        .accessibilityValue("\(StorageFormatting.bytes(usedSpace)) used, \(StorageFormatting.bytes(health.spendable)) available to use, and \(StorageFormatting.bytes(min(health.freeSpace, health.reserve))) kept as a safety cushion")
    }

    private var storageBreakdown: some View {
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What’s taking up space").font(.title2.weight(.semibold))
                        Text("The largest groups in the folders Headroom can see.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("See all files") { model.destination = .explore }
                }

                if storageGroups.isEmpty {
                    InlineEmptyState(icon: "externaldrive", title: "Checking your folders", message: "This view will fill in as Headroom learns what is on your Mac.")
                } else {
                    ForEach(storageGroups.prefix(5)) { group in
                        HStack(spacing: 13) {
                            Image(systemName: group.friendlyIcon)
                                .foregroundStyle(Palette.mint)
                                .frame(width: 34, height: 34)
                                .background(Palette.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(group.name).font(.headline)
                                    Spacer()
                                    Text(StorageFormatting.bytes(group.bytes)).font(.headline).monospacedDigit()
                                }
                                Text(group.friendlyDescription).font(.caption).foregroundStyle(.secondary)
                                GeometryReader { proxy in
                                    Capsule().fill(.secondary.opacity(0.12))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Palette.mint.opacity(0.78))
                                                .frame(width: proxy.size.width * relativeWidth(group))
                                        }
                                }
                                .frame(height: 5)
                                .accessibilityHidden(true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        if group.id != storageGroups.prefix(5).last?.id { Divider() }
                    }
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: model.current?.inaccessiblePaths.isEmpty == false ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundStyle(model.current?.inaccessiblePaths.isEmpty == false ? Palette.amber : Palette.mint)
                            .accessibilityHidden(true)
                        Text("Headroom checked \(model.current?.scannedItemCount ?? 0) files totaling \(StorageFormatting.bytes(model.current?.scannedBytes ?? 0)) in your selected folders.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if model.current?.inaccessiblePaths.isEmpty == false {
                            Button("Review access") { model.destination = .permissions }
                        }
                    }
                }
            }
        }
    }

    private var changedPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(eyebrow: "Since the last check", title: "What changed")
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Palette.mint).accessibilityHidden(true)
                }
                if let anomaly = model.anomalies.first {
                    Label("\(anomaly.name) grew more than usual", systemImage: "exclamationmark.circle")
                        .font(.callout.weight(.medium)).foregroundStyle(Palette.amber)
                }
                if model.deltas.isEmpty {
                    InlineEmptyState(icon: "clock.arrow.2.circlepath", title: "Ready for a comparison", message: "After the next check, Headroom will show what used more space and what got smaller.")
                } else {
                    ForEach(model.deltas.prefix(4)) { delta in
                        HStack(spacing: 10) {
                            Image(systemName: delta.bytes >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(delta.bytes >= 0 ? Palette.amber : Palette.mint)
                                .accessibilityHidden(true)
                            Text(delta.name).lineLimit(1)
                            Spacer()
                            Text(delta.bytes >= 0 ? "Used \(StorageFormatting.bytes(delta.bytes)) more" : "Used \(StorageFormatting.bytes(abs(delta.bytes))) less")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(delta.bytes >= 0 ? Palette.amber : Palette.mint)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Divider()
                Button("See recent changes") { model.destination = .changes }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var nextActions: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(eyebrow: "Chosen for safety", title: "Ways to make space")
                    Spacer()
                    Image(systemName: "sparkles").foregroundStyle(Palette.mint).accessibilityHidden(true)
                }
                if model.recommendations.isEmpty {
                    InlineEmptyState(icon: "checkmark.seal", title: "Nothing needs your attention", message: model.isScanning ? "Suggestions will appear when this check finishes." : "Headroom did not find a useful, low-risk cleanup right now.")
                } else {
                    ForEach(model.recommendations.prefix(3)) { item in
                        Button { model.selectedRecommendation = item } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: item.kind))
                                    .foregroundStyle(item.risk.color)
                                    .frame(width: 30, height: 30)
                                    .background(item.risk.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).foregroundStyle(.primary).lineLimit(2)
                                    Text(item.friendlySafetyLabel + " · " + item.friendlyUndoLabel)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(StorageFormatting.bytes(item.recoveryBytes)).font(.headline).foregroundStyle(Palette.mint)
                                    Text("could be freed").font(.caption2).foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Review the files before making any changes")
                    }
                }
                Divider()
                Button("See all suggestions") { model.destination = .actions }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var heroExplanation: String {
        if !health.isHealthy {
            return "You are below the \(StorageFormatting.bytes(health.reserve)) safety cushion. Headroom can help you make room without guessing what is safe."
        }
        return "You can use about \(StorageFormatting.bytes(health.spendable)) more before reaching your \(StorageFormatting.bytes(health.reserve)) safety cushion."
    }

    private func fraction(_ bytes: Int64) -> Double {
        guard capacity > 0 else { return 0 }
        return min(1, max(0, Double(bytes) / Double(capacity)))
    }

    private func relativeWidth(_ group: StorageGroup) -> Double {
        guard let largest = storageGroups.first?.bytes, largest > 0 else { return 0 }
        return min(1, Double(group.bytes) / Double(largest))
    }

    private func icon(for kind: RecommendationKind) -> String {
        switch kind {
        case .generatedData: "arrow.clockwise"
        case .oldInstaller: "arrow.down.circle"
        case .largeRecentFile: "doc.badge.clock"
        case .duplicate: "doc.on.doc"
        case .cloudLocalCopy: "icloud.and.arrow.up"
        case .screenRecording: "record.circle"
        case .largeVideo: "film.stack"
        }
    }
}

private struct StorageLegend: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
