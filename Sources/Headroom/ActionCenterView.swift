import SwiftUI
import HeadroomCore

struct ActionCenterView: View {
    @EnvironmentObject private var model: AppModel
    @State private var targetGB = 25.0
    @State private var showingPlan = false

    private var plan: RecoveryPlan { model.recoveryPlan(targetGB: targetGB) }

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: "You stay in control",
                    title: "Make space",
                    subtitle: "Choose how much room you want. Headroom starts with the easiest, safest options and shows every file before anything changes."
                ) {
                    Button { model.findDuplicates() } label: {
                        Label(model.isFindingDuplicates ? "Looking…" : "Look for duplicate files", systemImage: "doc.on.doc")
                    }
                    .disabled(model.isFindingDuplicates || model.current == nil)
                }

                recoveryPlanner

                HStack(alignment: .bottom) {
                    SectionTitle(eyebrow: "Start with the first suggestion", title: "Your safest options")
                    Spacer()
                    Text(model.recommendations.isEmpty ? "No suggestions right now" : "\(model.recommendations.count) to review")
                        .font(.callout).foregroundStyle(.secondary)
                }

                if model.recommendations.isEmpty {
                    Panel {
                        InlineEmptyState(
                            icon: "checkmark.seal",
                            title: "Nothing needs cleaning up",
                            message: model.isScanning ? "Headroom is checking your folders now." : "Headroom did not find a useful, low-risk way to make space."
                        )
                    }

                } else {
                    ForEach(Array(model.recommendations.enumerated()), id: \.element.id) { index, recommendation in
                        RecommendationCard(rank: index + 1, recommendation: recommendation)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingPlan) { RecoveryPlanView(targetGB: targetGB, plan: plan) }
    }

    private var recoveryPlanner: some View {
        Panel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) { goalChooser; Divider().frame(height: 110); planSummary }
                VStack(alignment: .leading, spacing: 22) { goalChooser; Divider(); planSummary }
            }
        }
    }

    private var goalChooser: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("How much space would feel comfortable?", systemImage: "target")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.mint)
            Text("You can change this later. Headroom will never add risky actions just to reach the number.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                RecoveryGoalButton(title: "A little", amount: 10, selection: $targetGB)
                RecoveryGoalButton(title: "Comfortable", amount: 25, selection: $targetGB)
                RecoveryGoalButton(title: "A lot", amount: 50, selection: $targetGB)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var planSummary: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text(StorageFormatting.bytes(plan.estimatedRecovery))
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(plan.meetsTarget ? Palette.mint : Palette.amber)
                    .monospacedDigit()
                Text(plan.recommendations.isEmpty
                     ? "No safe suggestions are available yet."
                     : plan.meetsTarget
                        ? "A plan with \(plan.recommendations.count) clear step\(plan.recommendations.count == 1 ? "" : "s")."
                        : "The safe options available now do not quite reach \(Int(targetGB)) GB.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Review this plan") { showingPlan = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(plan.recommendations.isEmpty)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecoveryGoalButton: View {
    let title: String
    let amount: Double
    @Binding var selection: Double

    private var isSelected: Bool { selection == amount }

    var body: some View {
        Button { selection = amount } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold))
                Text("\(Int(amount)) GB").font(.caption).foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(minWidth: 92, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Palette.mint.opacity(0.16) : .secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Palette.mint.opacity(0.65) : Color(nsColor: .separatorColor).opacity(0.4)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), free \(Int(amount)) gigabytes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RecommendationCard: View {
    @EnvironmentObject private var model: AppModel
    let rank: Int
    let recommendation: Recommendation

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 15) {
                    Text("\(rank)")
                        .font(.headline)
                        .foregroundStyle(Palette.mint)
                        .frame(width: 34, height: 34)
                        .background(Palette.mint.opacity(0.12), in: Circle())
                        .accessibilityLabel("Suggestion \(rank)")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recommendation.title).font(.title3.weight(.semibold))
                        Text(recommendation.detail).font(.body).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let evidence = recommendation.evidence {
                            Label(evidence, systemImage: "magnifyingglass")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 20)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(StorageFormatting.bytes(recommendation.recoveryBytes))
                            .font(.title2.weight(.semibold)).foregroundStyle(Palette.mint).monospacedDigit()
                        Text("could be freed").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 22) { explanationRows }
                    VStack(alignment: .leading, spacing: 10) { explanationRows }
                }

                HStack {
                    Text("\(recommendation.affectedItems.count) file\(recommendation.affectedItems.count == 1 ? "" : "s") included")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("I still need these files") { model.giveFeedback(recommendation, reason: .stillNeeded) }
                        Button("This doesn’t feel safe") { model.giveFeedback(recommendation, reason: .feelsUnsafe) }
                        Button("I don’t understand this suggestion") { model.giveFeedback(recommendation, reason: .unclear) }
                        Button("This isn’t relevant to me") { model.giveFeedback(recommendation, reason: .notRelevant) }
                        Button("Remind me next week") { model.snooze(recommendation) }
                        Divider()
                        Button("Never suggest these files") { model.protect(recommendation) }
                    } label: {
                        Label("More choices", systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    Button("Review files") { model.selectedRecommendation = recommendation }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    @ViewBuilder
    private var explanationRows: some View {
        FriendlyFact(icon: "checkmark.shield", title: recommendation.friendlySafetyLabel, detail: recommendation.friendlyReason, color: recommendation.risk.color)
        FriendlyFact(icon: "arrow.right.circle", title: "What Headroom will do", detail: recommendation.friendlyAction, color: .secondary)
        FriendlyFact(icon: "arrow.uturn.backward.circle", title: "If you need it again", detail: recommendation.friendlyUndoLabel, color: Palette.mint)
    }
}

private struct FriendlyFact: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct RecoveryPlanView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let targetGB: Double
    let plan: RecoveryPlan

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your safest plan").font(.title2.weight(.semibold))
                    Text(plan.meetsTarget
                         ? "These steps could free \(StorageFormatting.bytes(plan.estimatedRecovery)). Review them one at a time."
                         : "These are the safe options Headroom found. They may not reach \(Int(targetGB)) GB yet.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(plan.recommendations.enumerated()), id: \.element.id) { index, recommendation in
                        HStack(spacing: 14) {
                            Text("\(index + 1)").font(.headline).foregroundStyle(Palette.mint)
                                .frame(width: 30, height: 30).background(Palette.mint.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(recommendation.title).font(.headline)
                                Text(recommendation.friendlySafetyLabel + " · " + recommendation.friendlyUndoLabel)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(StorageFormatting.bytes(recommendation.recoveryBytes)).font(.headline).foregroundStyle(Palette.mint)
                            Button("Review") {
                                dismiss()
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(180))
                                    model.selectedRecommendation = recommendation
                                }
                            }
                        }
                        .padding(16)
                        .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Label("Nothing happens until you approve it", systemImage: "checkmark.shield").foregroundStyle(Palette.mint)
                Spacer()
                Text("You can skip any suggestion.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(width: 740, height: 540)
    }
}

struct RecommendationDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let recommendation: Recommendation
    @State private var confirmation = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Review before making changes").font(.caption.weight(.semibold)).foregroundStyle(Palette.mint)
                        Text(recommendation.title).font(.title2.weight(.semibold))
                    Text("Could free up to \(StorageFormatting.bytes(recommendation.recoveryBytes)) from \(recommendation.affectedItems.count) file\(recommendation.affectedItems.count == 1 ? "" : "s").")
                            .foregroundStyle(.secondary)
                        if let evidence = recommendation.evidence {
                            Label(evidence, systemImage: "magnifyingglass")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                }
                HStack(spacing: 18) {
                    Label(recommendation.friendlySafetyLabel, systemImage: "checkmark.shield")
                    Label(recommendation.friendlyUndoLabel, systemImage: "arrow.uturn.backward.circle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            Divider()

            List(recommendation.affectedItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: icon(for: item.url.pathExtension)).font(.title2).foregroundStyle(Palette.mint).frame(width: 34).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.url.lastPathComponent).lineLimit(1)
                        Text(item.url.deletingLastPathComponent().lastPathComponent.isEmpty ? "On this Mac" : "In \(item.url.deletingLastPathComponent().lastPathComponent)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Label(model.explanation(for: item).headline, systemImage: model.explanation(for: item).source == .ai ? "sparkles" : "lightbulb")
                            .font(.caption).foregroundStyle(model.explanation(for: item).source == .ai ? Palette.mint : .secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(StorageFormatting.bytes(item.allocatedSize)).monospacedDigit()
                    Button { model.selectedExplanationItem = item } label: { Image(systemName: "sparkles") }
                        .help("Explain what this file is likely used for")
                        .accessibilityLabel("Explain \(item.url.lastPathComponent)")
                    Button { model.reveal(item) } label: { Image(systemName: "folder") }.help("Show in Finder")
                    Button { model.quickLook(item) } label: { Image(systemName: "eye") }.help("Open a preview")
                    Button { model.protect(item) } label: { Image(systemName: "shield") }.help("Never suggest this file")
                }
                .padding(.vertical, 5)
            }

            Divider()
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(actionDescription, systemImage: recommendation.kind == .cloudLocalCopy ? "icloud.and.arrow.up" : "trash")
                        .font(.headline).foregroundStyle(Palette.mint)
                    Text(recoveryDescription).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.trustMode == .observer {
                    Button("Allow approved cleanups") { model.trustMode = .advisor }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Button(recommendation.kind == .cloudLocalCopy ? "Free this space" : "Move files to Trash") { confirmation = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(recommendation.kind == .cloudLocalCopy ? Palette.mint : Palette.coral)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 780, minHeight: 580)
        .confirmationDialog(confirmationTitle, isPresented: $confirmation) {
            if recommendation.kind == .cloudLocalCopy {
                Button("Remove downloads from this Mac") { model.evictCloudCopies(recommendation) }
            } else {
                Button("Move files to Trash", role: .destructive) { model.moveToTrash(recommendation) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(recoveryDescription)
        }
        .sheet(item: $model.selectedExplanationItem) { item in
            FileExplanationSheet(item: item)
                .environmentObject(model)
        }
    }

    private var actionDescription: String {
        recommendation.kind == .cloudLocalCopy ? "Your iCloud files will stay safe" : "The files will move to Trash"
    }

    private var recoveryDescription: String {
        recommendation.kind == .cloudLocalCopy
            ? "Only the downloaded copies leave this Mac. The files stay in iCloud and download again when you open them."
            : "You can put the files back until you empty Trash. Headroom checks how much space was actually freed afterward."
    }

    private var confirmationTitle: String {
        recommendation.kind == .cloudLocalCopy
            ? "Free space used by these \(recommendation.affectedItems.count) downloads?"
            : "Move these \(recommendation.affectedItems.count) files to Trash?"
    }

    private func icon(for ext: String) -> String {
        switch ext.lowercased() {
        case "mov", "mp4", "m4v": "film"
        case "zip", "dmg", "pkg", "xip": "shippingbox"
        default: "doc"
        }
    }
}

private struct FileExplanationSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let item: ScannedItem

    private var explanation: FileUseExplanation { model.explanation(for: item) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Help me understand this file").font(.caption.weight(.semibold)).foregroundStyle(Palette.mint)
                    Text(item.url.lastPathComponent).font(.title2.weight(.semibold)).lineLimit(2)
                    Text("In \(item.url.deletingLastPathComponent().lastPathComponent)")
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack {
                                Label(explanation.source.rawValue, systemImage: explanation.source == .ai ? "sparkles" : "lock.fill")
                                    .font(.caption.weight(.semibold)).foregroundStyle(explanation.source == .ai ? Palette.mint : .secondary)
                                if explanation.previewWasAnalyzed {
                                    Label("Preview inspected", systemImage: "photo")
                                        .font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
                                }
                                Spacer()
                                StatusPill(text: explanation.confidence.label, color: explanation.confidence.color)
                            }
                            Text(explanation.headline).font(.title3.weight(.semibold))
                            Text(explanation.summary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Panel {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: explanation.decision.icon)
                                .font(.title2)
                                .foregroundStyle(explanation.decision.color)
                                .frame(width: 42, height: 42)
                                .background(explanation.decision.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Headroom’s call").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(explanation.decision.title).font(.title3.weight(.semibold)).foregroundStyle(explanation.decision.color)
                                Text(explanation.decisionReason).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let suggestion = explanation.organizationSuggestion, !suggestion.isEmpty {
                        Panel {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Where this belongs", systemImage: "folder.badge.gearshape")
                                    .font(.headline).foregroundStyle(Palette.mint)
                                Text(suggestion).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why Headroom thinks this").font(.headline)
                        ForEach(explanation.evidence, id: \.self) { fact in
                            Label(fact, systemImage: "checkmark.circle")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }

                    Panel {
                        Label(explanation.caution, systemImage: "exclamationmark.shield")
                            .font(.callout).foregroundStyle(Palette.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    aiSecondOpinion
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 610)
    }

    @ViewBuilder
    private var aiSecondOpinion: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Want a more specific recommendation?").font(.headline)
            if model.isExplaining(item) {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(model.aiImageAnalysisEnabled && ["jpg", "jpeg", "png", "heic", "tif", "tiff", "gif"].contains(item.url.pathExtension.lowercased())
                         ? "Asking AI to interpret the metadata and reduced preview…"
                         : "Asking AI to interpret the metadata…")
                        .foregroundStyle(.secondary)
                }
            } else if model.aiExplanationsEnabled && model.hasAIAPIKey {
                Text(model.aiImageAnalysisEnabled
                     ? "AI receives the file metadata and, for supported images, a reduced preview. This can recognize product screenshots and visual references. The complete path is never sent."
                     : "AI receives only the file name, a few folder names, size, age, and the clues above. It does not receive file contents or the complete path.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Ask AI what I should do") { model.requestAIExplanation(for: item) }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("On-device recommendations are always private. To use optional AI analysis, turn it on and add your own OpenAI API key in Headroom Settings.")
                    .font(.callout).foregroundStyle(.secondary)
                Label("No file contents leave your Mac", systemImage: "lock.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.mint)
            }
            if let error = model.aiExplanationError {
                Text(error).font(.caption).foregroundStyle(Palette.amber)
            }
        }
    }
}
