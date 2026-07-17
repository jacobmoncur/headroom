import SwiftUI
import HeadroomCore

struct OrganizeView: View {
    @EnvironmentObject private var model: AppModel

    private var localCount: Int { model.organizationSuggestions.filter { $0.source == .onDevice }.count }
    private var aiCount: Int { model.organizationSuggestions.filter { $0.source == .ai }.count }

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "Memory organization, not just cleanup",
                    title: "Put related files back together",
                    subtitle: "Headroom finds files that appear to belong to the same project or topic—even when they are scattered across different folders. Nothing moves until you decide."
                ) {
                    Button { model.requestAIOrganizationPlan() } label: {
                        Label(model.isOrganizingWithAI ? "Looking for connections…" : "Ask AI for deeper connections",
                              systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isOrganizingWithAI || model.current?.largeItems.isEmpty != false)
                }

                howItWorks

                HStack(alignment: .bottom) {
                    SectionTitle(eyebrow: "Suggested collections", title: "Related files in different places")
                    Spacer()
                    if !model.organizationSuggestions.isEmpty {
                        Text("\(localCount) found locally\(aiCount > 0 ? " · \(aiCount) from AI" : "")")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }

                if model.organizationSuggestions.isEmpty {
                    Panel {
                        InlineEmptyState(
                            icon: "square.grid.3x3.topleft.filled",
                            title: model.isScanning ? "Still looking for relationships" : "No strong groups yet",
                            message: "Headroom avoids weak guesses. Add the folders where your projects live, check storage again, or ask AI to compare metadata across the largest files."
                        )
                    }
                } else {
                    ForEach(model.organizationSuggestions) { suggestion in
                        OrganizationCard(suggestion: suggestion)
                    }
                }

                if let error = model.aiOrganizationError {
                    Panel {
                        Label(error, systemImage: "exclamationmark.bubble")
                            .font(.callout).foregroundStyle(Palette.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1_020)
            .frame(maxWidth: .infinity)
        }
    }

    private var howItWorks: some View {
        Panel {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) { explanationFacts }
                VStack(alignment: .leading, spacing: 16) { explanationFacts }
            }
        }
    }

    @ViewBuilder
    private var explanationFacts: some View {
        organizationFact(icon: "link", title: "Find the relationship", detail: "Names, folders, dates, apps, and file types reveal likely projects and topics.")
        organizationFact(icon: "folder.badge.plus", title: "Suggest one home", detail: "Every group includes a proposed category and a plain-language reason.")
        organizationFact(icon: "hand.raised", title: "You make the move", detail: "Headroom only recommends organization; it never silently relocates a file.")
    }

    private func organizationFact(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Palette.mint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OrganizationCard: View {
    @EnvironmentObject private var model: AppModel
    let suggestion: OrganizationSuggestion
    @State private var isExpanded = false

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: suggestion.source == .ai ? "sparkles" : "link")
                        .font(.title2).foregroundStyle(Palette.mint)
                        .frame(width: 44, height: 44)
                        .background(Palette.mint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(suggestion.title).font(.title3.weight(.semibold))
                            StatusPill(text: suggestion.source.rawValue, color: suggestion.source == .ai ? Palette.mint : .secondary)
                        }
                        Text(suggestion.detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(suggestion.items.count) files").font(.headline).monospacedDigit()
                        Text("in \(suggestion.distinctFolderCount) folders · \(StorageFormatting.bytes(suggestion.totalBytes))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) { recommendationFacts }
                    VStack(alignment: .leading, spacing: 12) { recommendationFacts }
                }

                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(spacing: 0) {
                        ForEach(suggestion.items.prefix(20)) { item in
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: item)).foregroundStyle(Palette.mint).frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.url.lastPathComponent).lineLimit(1)
                                    Text(item.url.deletingLastPathComponent().path)
                                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1).help(item.url.path)
                                }
                                Spacer()
                                Text(StorageFormatting.bytes(item.allocatedSize)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                Button { model.quickLook(item) } label: { Image(systemName: "eye") }
                                    .buttonStyle(.plain).help("Open a preview")
                                Button { model.reveal(item) } label: { Image(systemName: "folder") }
                                    .buttonStyle(.plain).help("Show in Finder")
                            }
                            .padding(.vertical, 8)
                            if item.id != suggestion.items.prefix(20).last?.id { Divider() }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(isExpanded ? "Hide files" : "Review every file")
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationFacts: some View {
        fact(icon: "folder", title: "Suggested home", detail: suggestion.suggestedFolder, color: Palette.mint)
        fact(icon: "questionmark.circle", title: "Why", detail: suggestion.reason, color: .secondary)
        fact(icon: "checkmark.shield", title: suggestion.confidence.label, detail: "A suggestion only—no files have moved.", color: suggestion.confidence == .high ? Palette.mint : Palette.amber)
    }

    private func fact(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func icon(for item: ScannedItem) -> String {
        switch item.fileType {
        case "Images": "photo"
        case "Video": "film"
        case "Documents": "doc.text"
        case "Project files": "chevron.left.forwardslash.chevron.right"
        default: "doc"
        }
    }
}
