import SwiftUI
import HeadroomCore

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                eyebrow: "A record you can trust",
                title: "Past cleanups",
                subtitle: "See what Headroom changed and how much space your Mac actually gained."
            ) { EmptyView() }

            if model.actions.isEmpty {
                Panel {
                    InlineEmptyState(
                        icon: "clock.arrow.circlepath",
                        title: "No cleanups yet",
                        message: "When you approve a cleanup, Headroom will keep a clear record here—including the result."
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.actions) { action in
                    let status = action.effectiveVerificationStatus
                    let isPending = status == .awaitingTrash || status == .verifying
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: isPending ? "clock.badge.questionmark.fill" : (status == .verified ? "checkmark.circle.fill" : "exclamationmark.circle.fill"))
                            .font(.title3)
                            .foregroundStyle(status == .verified ? Palette.mint : Palette.amber)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title).font(.headline)
                            Text("\(action.itemCount) file\(action.itemCount == 1 ? "" : "s") · \(action.performedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                            if let message = action.verificationMessage {
                                Text(message).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if isPending {
                                Text(StorageFormatting.bytes(action.expectedBytes)).font(.headline).monospacedDigit()
                                Text(status == .awaitingTrash ? "possible after emptying Trash" : "expected from this cleanup")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button("Check results") { model.verify(action) }
                                    .buttonStyle(.borderedProminent).controlSize(.small)
                            } else {
                                Text(StorageFormatting.bytes(action.recoveredBytes)).font(.headline).monospacedDigit()
                                Text("free-space change observed").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .contain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(30)
    }
}

struct PermissionsView: View {
    @EnvironmentObject private var model: AppModel
    private var inaccessible: [String] { model.current?.inaccessiblePaths ?? [] }

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "Private by design",
                    title: "Privacy & folders",
                    subtitle: "Choose where Headroom can look and which files it should never suggest cleaning up."
                ) {
                    Button("Add a folder", action: model.addFolder)
                }

                privacyHero
                neverSuggestPanel
                monitoredFoldersPanel

                if !model.protectedPaths.isEmpty { protectedItemsPanel }
                if !inaccessible.isEmpty { unavailablePanel }
            }
            .padding(30)
            .frame(maxWidth: 940)
            .frame(maxWidth: .infinity)
        }
    }

    private var privacyHero: some View {
        Panel {
            HStack(alignment: .top, spacing: 17) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.mint)
                    .frame(width: 54, height: 54)
                    .background(Palette.mint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local unless you explicitly ask AI").font(.title3.weight(.semibold))
                    Text("Storage checks stay on this Mac. Headroom sends metadata—or a reduced image preview—only when you explicitly ask its optional AI features.")
                        .font(.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(inaccessible.isEmpty ? "Headroom can check all selected folders" : "Some selected folders could not be checked", systemImage: inaccessible.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(inaccessible.isEmpty ? Palette.mint : Palette.amber)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var neverSuggestPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Files Headroom should never suggest").font(.headline)
                Text("Protected files still appear in your storage totals, but Headroom leaves them out of cleanup suggestions.")
                    .font(.callout).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(["Images", "Video", "Audio", "Documents", "Source code"], id: \.self) { type in
                        Button { model.toggleProtectedFileType(type) } label: {
                            Label(type, systemImage: model.protectedFileTypes.contains(type) ? "checkmark.shield.fill" : "shield")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(model.protectedFileTypes.contains(type) ? Palette.mint : .secondary)
                        .accessibilityLabel("\(type), \(model.protectedFileTypes.contains(type) ? "never suggest" : "may be suggested")")
                    }
                }
            }
        }
    }

    private var monitoredFoldersPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Folders Headroom checks").font(.headline)
                        Text("Add or remove folders at any time.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Add a folder", action: model.addFolder)
                }
                ForEach(StorageScanner.defaultRoots(), id: \.path) { url in folderRow(url: url, canRemove: false) }
                ForEach(model.extraRoots, id: \.path) { url in folderRow(url: url, canRemove: true) }
            }
        }
    }

    private var protectedItemsPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 11) {
                Text("Files you told Headroom to leave alone").font(.headline)
                ForEach(Array(model.protectedPaths).sorted(), id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(systemName: "shield.fill").foregroundStyle(Palette.mint).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: path).lastPathComponent).lineLimit(1)
                            Text(path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).help(path)
                        }
                        Spacer()
                        Button("Allow suggestions") { model.unprotect(path) }
                    }
                }
            }
        }
    }

    private var unavailablePanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Headroom could not check \(inaccessible.count) location\(inaccessible.count == 1 ? "" : "s")").font(.headline)
                        Text("Your totals may be incomplete. You can allow broader access in System Settings, or keep using Headroom with the folders it can see.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                    .buttonStyle(.borderedProminent)
                }
                DisclosureGroup("Show unavailable locations") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(inaccessible.prefix(20), id: \.self) { path in
                            Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func folderRow(url: URL, canRemove: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "folder.fill").foregroundStyle(Palette.mint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent).font(.callout.weight(.medium))
                Text(url.deletingLastPathComponent().path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if canRemove {
                Button("Stop checking") { model.removeFolder(url) }
            } else {
                Text("Included").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section("Safety cushion") {
                HStack {
                    Text("Warn me when free space approaches")
                    Slider(value: $model.reserveGB, in: 10...250, step: 5)
                    Text("\(Int(model.reserveGB)) GB").monospacedDigit().frame(width: 60, alignment: .trailing)
                }
                Text("This keeps breathing room for macOS updates, downloads, and everyday work.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("What Headroom may do") {
                Picker("File changes", selection: $model.trustMode) {
                    Text("Suggest only").tag(AppModel.TrustMode.observer)
                    Text("Allow cleanups I approve").tag(AppModel.TrustMode.advisor)
                }
                Text(model.trustMode == .observer
                     ? "Headroom can explain and suggest, but it cannot change files."
                     : "Headroom can act only after you review the files and approve the specific cleanup.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("Storage checks happen on this Mac", systemImage: "lock.fill")
                Label("Headroom never empties Trash", systemImage: "trash.slash")
            }
            Section("AI recommendations") {
                Toggle("Use OpenAI for recommendations", isOn: $model.aiExplanationsEnabled)
                Text("Headroom works locally first. When you explicitly ask AI, it sends the file name, a few parent-folder names, size, age, and local clues—never the complete path.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Let AI inspect reduced image previews", isOn: $model.aiImageAnalysisEnabled)
                    .disabled(!model.aiExplanationsEnabled)
                Text("When this is on, asking AI about a supported image also sends a reduced JPEG preview. This lets Headroom recognize product screenshots and visual references. Other file contents are never sent.")
                    .font(.caption).foregroundStyle(.secondary)
                if model.hasAIAPIKey {
                    Label("Your API key is saved in this Mac’s Keychain", systemImage: "key.fill")
                        .font(.caption).foregroundStyle(Palette.mint)
                    Button("Remove saved API key", role: .destructive) { model.removeAIAPIKey() }
                } else {
                    SecureField("OpenAI API key", text: $apiKey)
                    Button("Save API key") {
                        model.saveAIAPIKey(apiKey)
                        if model.hasAIAPIKey { apiKey = "" }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                DisclosureGroup("Advanced") {
                    TextField("Model", text: $model.aiModel)
                    Text("The default works well for short metadata-only explanations. Change this only if you manage your own API model access.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = model.aiExplanationError {
                    Text(message).font(.caption).foregroundStyle(Palette.amber)
                }
            }
            Section("Alpha diagnostics") {
                Text("Export a small report when something looks wrong. It includes scan timing, counts, recommendation types, and cleanup outcomes—not file names or contents.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Include file paths in this export", isOn: $model.includePathsInDiagnostics)
                Text(model.includePathsInDiagnostics
                     ? "The exported file may include private folder and file names. Review it before sharing."
                     : "File and folder paths stay out of the report.")
                    .font(.caption).foregroundStyle(model.includePathsInDiagnostics ? Palette.amber : .secondary)
                Button("Export diagnostics…") { model.exportDiagnostics() }
            }
            if !model.dismissedRecommendationIDs.isEmpty || !model.snoozedRecommendationUntil.isEmpty {
                Section("Hidden suggestions") {
                    HStack {
                        Text("\(model.dismissedRecommendationIDs.count) hidden · \(model.snoozedRecommendationUntil.count) saved for later")
                        Spacer()
                        Button("Show them again") { model.restoreDismissedRecommendations() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "externaldrive").foregroundStyle(Palette.mint)
                Text("Headroom").font(.headline)
                Spacer()
                StatusPill(text: model.health.isHealthy ? "Room to breathe" : "Running low", color: model.health.isHealthy ? Palette.mint : Palette.coral)
            }
            Divider()
            Text(StorageFormatting.bytes(model.health.freeSpace)).font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("free on this Mac").foregroundStyle(.secondary)
            Text(model.health.isHealthy
                 ? "\(StorageFormatting.bytes(model.health.spendable)) available before your safety cushion"
                 : "Below your \(StorageFormatting.bytes(model.health.reserve)) safety cushion")
                .font(.callout).foregroundStyle(model.health.isHealthy ? .secondary : Palette.coral)
            if model.isScanning {
                ProgressView(value: model.scanFraction).tint(Palette.mint)
                Text("Checking folders · \(StorageFormatting.bytes(model.scannedBytes)) counted")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let days = model.health.runwayDays {
                Text("You may reach your safety cushion in about \(days) days").font(.caption)
            }
            Divider()
            HStack {
                Button("Check Again") { model.scan() }.disabled(model.isScanning)
                Spacer()
                Button("Open Headroom") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
