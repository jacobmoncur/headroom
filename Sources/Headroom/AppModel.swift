import AppKit
import Combine
import Foundation
import HeadroomCore
import UniformTypeIdentifiers
@preconcurrency import QuickLookUI

@MainActor
final class QuickLookController: NSObject, @MainActor QLPreviewPanelDataSource {
    private var items: [URL] = []
    func show(_ url: URL) {
        items = [url]
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self; panel.reloadData(); panel.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { items.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { items[index] as NSURL }
}

@MainActor
final class AppModel: ObservableObject {
    enum TrustMode: String, CaseIterable, Identifiable { case observer = "Observer", advisor = "Advisor"; var id: String { rawValue } }
    enum Destination: String, CaseIterable, Identifiable {
        case home = "My Storage", actions = "Make Space", explore = "What’s Using Space", changes = "Recent Changes", history = "Past Cleanups", permissions = "Privacy & Folders"
        var id: String { rawValue }
        var icon: String { switch self { case .home: "house"; case .actions: "sparkles"; case .explore: "externaldrive"; case .changes: "chart.xyaxis.line"; case .history: "clock.arrow.circlepath"; case .permissions: "hand.raised" } }
    }

    @Published var destination: Destination = .home
    @Published var hasCompletedOnboarding: Bool { didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") } }
    @Published var snapshots: [StorageSnapshot] = []
    @Published var actions: [ActionRecord] = []
    @Published var feedback: [RecommendationFeedback] = []
    @Published var recommendations: [Recommendation] = []
    @Published var duplicateGroups: [[ScannedItem]] = []
    @Published var isScanning = false
    @Published var isFindingDuplicates = false
    @Published var scanPhase = "Ready"
    @Published var scannedItems = 0
    @Published var scannedBytes: Int64 = 0
    @Published var scanFraction: Double = 0
    @Published var errorMessage: String?
    @Published var selectedRecommendation: Recommendation?
    @Published var reserveGB: Double { didSet { UserDefaults.standard.set(reserveGB, forKey: "reserveGB") } }
    @Published var trustMode: TrustMode { didSet { UserDefaults.standard.set(trustMode.rawValue, forKey: "trustMode") } }
    @Published var protectedPaths: Set<String> { didSet { UserDefaults.standard.set(Array(protectedPaths), forKey: "protectedPaths") } }
    @Published var protectedFileTypes: Set<String> { didSet { UserDefaults.standard.set(Array(protectedFileTypes), forKey: "protectedFileTypes") } }
    @Published var dismissedRecommendationIDs: Set<String> { didSet { UserDefaults.standard.set(Array(dismissedRecommendationIDs), forKey: "dismissedRecommendationIDs") } }
    @Published var snoozedRecommendationUntil: [String: TimeInterval] { didSet { UserDefaults.standard.set(snoozedRecommendationUntil, forKey: "snoozedRecommendationUntil") } }
    @Published var includePathsInDiagnostics: Bool { didSet { UserDefaults.standard.set(includePathsInDiagnostics, forKey: "includePathsInDiagnostics") } }
    @Published var aiExplanationsEnabled: Bool { didSet { UserDefaults.standard.set(aiExplanationsEnabled, forKey: "aiExplanationsEnabled") } }
    @Published var aiModel: String { didSet { UserDefaults.standard.set(aiModel, forKey: "aiExplanationModel") } }
    @Published private(set) var hasAIAPIKey = false
    @Published private(set) var isExplainingItemIDs = Set<String>()
    @Published var aiExplanationError: String?
    @Published var selectedExplanationItem: ScannedItem?
    @Published var extraRoots: [URL] { didSet {
        UserDefaults.standard.set(extraRoots.map(\.path), forKey: "extraRoots")
        restartFileMonitoring()
    } }
    @Published private var provisionalSnapshot: StorageSnapshot?

    private let store = HistoryStore()
    private let quickLookController = QuickLookController()
    private var periodicReconciliationTask: Task<Void, Never>?
    private var eventReconciliationTask: Task<Void, Never>?
    private var fileSystemMonitor: FileSystemMonitor?
    private var scanAgainWhenFinished = false
    private var fullScanRequested = false
    private var pendingChangedPaths = Set<String>()
    private var rootIndex: [String: StorageSnapshot] = [:]
    private var aiExplanations: [String: FileUseExplanation] = [:]
    var current: StorageSnapshot? { snapshots.last ?? provisionalSnapshot }
    var previous: StorageSnapshot? { snapshots.dropLast().last }
    var health: StorageHealth { StorageAdvisor.health(current: current, previous: previous, reserve: Int64(reserveGB * 1_000_000_000)) }
    var deltas: [StorageDelta] { StorageAdvisor.deltas(current: current, previous: previous) }
    var anomalies: [StorageDelta] { StorageAdvisor.anomalies(in: deltas) }
    var menuBarLabel: String { current.map { StorageFormatting.bytes($0.freeSpace) } ?? "Headroom" }
    var lastScanDate: Date? { snapshots.last?.capturedAt }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let saved = UserDefaults.standard.double(forKey: "reserveGB")
        self.reserveGB = saved == 0 ? 50 : saved
        self.trustMode = TrustMode(rawValue: UserDefaults.standard.string(forKey: "trustMode") ?? "") ?? .observer
        self.protectedPaths = Set(UserDefaults.standard.stringArray(forKey: "protectedPaths") ?? [])
        self.protectedFileTypes = Set(UserDefaults.standard.stringArray(forKey: "protectedFileTypes") ?? [])
        self.dismissedRecommendationIDs = Set(UserDefaults.standard.stringArray(forKey: "dismissedRecommendationIDs") ?? [])
        self.snoozedRecommendationUntil = UserDefaults.standard.dictionary(forKey: "snoozedRecommendationUntil") as? [String: TimeInterval] ?? [:]
        self.includePathsInDiagnostics = UserDefaults.standard.bool(forKey: "includePathsInDiagnostics")
        self.aiExplanationsEnabled = UserDefaults.standard.bool(forKey: "aiExplanationsEnabled")
        self.aiModel = UserDefaults.standard.string(forKey: "aiExplanationModel") ?? "gpt-4o-mini"
        self.hasAIAPIKey = KeychainSecretStore.loadAPIKey() != nil
        self.extraRoots = (UserDefaults.standard.stringArray(forKey: "extraRoots") ?? []).map(URL.init(fileURLWithPath:))
    }

    func start() async {
        snapshots = await store.loadSnapshots()
        actions = await store.loadActions()
        feedback = await store.loadFeedback()
        rootIndex = await store.loadRootIndex()
        if UserDefaults.standard.bool(forKey: "scanWasInterrupted") {
            scanPhase = "A previous scan was interrupted. Headroom will safely start again."
        }
        if !snapshots.isEmpty { hasCompletedOnboarding = true }
        refreshRecommendations()
        let needsFreshScan = snapshots.last.map { Date.now.timeIntervalSince($0.capturedAt) > 15 * 60 || $0.fileTypes == nil } ?? true
        if hasCompletedOnboarding && needsFreshScan { scan() }
        restartFileMonitoring()
        periodicReconciliationTask?.cancel()
        periodicReconciliationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
                guard !Task.isCancelled else { return }
                self?.scan()
            }
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        restartFileMonitoring()
        scan()
    }

    func scan() {
        beginScan(changedPaths: nil)
    }

    private func beginScan(changedPaths: [String]?) {
        guard !isScanning else {
            scanAgainWhenFinished = true
            if let changedPaths { pendingChangedPaths.formUnion(changedPaths) }
            else { fullScanRequested = true }
            return
        }
        isScanning = true; scanPhase = "Preparing scan"; scannedItems = 0; scannedBytes = 0; scanFraction = 0; errorMessage = nil
        UserDefaults.standard.set(true, forKey: "scanWasInterrupted")
        if snapshots.isEmpty { provisionalSnapshot = StorageScanner.volumeOverview() }
        let roots = StorageScanner.normalizedRoots(StorageScanner.defaultRoots() + extraRoots)
        let existingIndex = rootIndex
        let activeRootPaths = Set(roots.map(\.path))
        let hasCompleteIndex = activeRootPaths.isSubset(of: Set(existingIndex.keys))
        let changedRoots = changedPaths.map { paths in
            roots.filter { root in paths.contains(where: { $0 == root.path || $0.hasPrefix(root.path + "/") }) }
        } ?? []
        let rootsToScan = hasCompleteIndex && !changedRoots.isEmpty ? changedRoots : roots
        let isIncremental = rootsToScan.count < roots.count && hasCompleteIndex
        Task {
            let result = await Task.detached(priority: .utility) {
                let updates = StorageScanner.scanIndex(roots: rootsToScan) { progress in
                    Task { @MainActor in
                        self.scanPhase = progress.phase; self.scannedItems = progress.items
                        self.scannedBytes = progress.scannedBytes; self.scanFraction = progress.fraction
                    }
                }
                var updatedIndex = isIncremental ? existingIndex : [:]
                for (path, snapshot) in updates { updatedIndex[path] = snapshot }
                updatedIndex = updatedIndex.filter { activeRootPaths.contains($0.key) }
                return (StorageScanner.mergedSnapshot(from: updatedIndex, roots: roots), updatedIndex)
            }.value
            let snapshot = result.0
            rootIndex = result.1
            do {
                try await store.save(rootIndex: rootIndex)
                try await store.save(snapshot: snapshot)
            } catch { errorMessage = error.localizedDescription }
            snapshots.append(snapshot)
            provisionalSnapshot = nil
            isScanning = false; scanPhase = "Up to date"; scannedItems = snapshot.scannedItemCount
            scannedBytes = snapshot.scannedBytes; scanFraction = 1
            UserDefaults.standard.set(false, forKey: "scanWasInterrupted")
            refreshRecommendations()
            if scanAgainWhenFinished {
                scanAgainWhenFinished = false
                let nextPaths = fullScanRequested ? nil : Array(pendingChangedPaths)
                fullScanRequested = false; pendingChangedPaths.removeAll()
                beginScan(changedPaths: nextPaths)
            }
        }
    }

    func findDuplicates() {
        guard let items = current?.largeItems, !isFindingDuplicates else { return }
        isFindingDuplicates = true
        Task {
            duplicateGroups = await Task.detached(priority: .utility) { StorageAdvisor.exactDuplicateGroups(in: items) }.value
            isFindingDuplicates = false; refreshRecommendations()
        }
    }

    func refreshRecommendations() {
        recommendations = current.map { snapshot in
            StorageAdvisor.recommendations(for: snapshot, duplicates: duplicateGroups,
                                           protectedPaths: protectedPaths, protectedFileTypes: protectedFileTypes)
                .filter { !dismissedRecommendationIDs.contains($0.id) && snoozedRecommendationUntil[$0.id, default: 0] <= Date.now.timeIntervalSince1970 }
        } ?? []
    }

    func recoveryPlan(targetGB: Double) -> RecoveryPlan {
        StorageAdvisor.recoveryPlan(targetBytes: Int64(targetGB * 1_000_000_000), from: recommendations)
    }

    func dismiss(_ recommendation: Recommendation) {
        dismissedRecommendationIDs.insert(recommendation.id); refreshRecommendations()
    }

    func giveFeedback(_ recommendation: Recommendation, reason: RecommendationFeedbackReason) {
        let entry = RecommendationFeedback(recommendationID: recommendation.id,
                                           recommendationKind: recommendation.kind, reason: reason)
        feedback.insert(entry, at: 0)
        dismissedRecommendationIDs.insert(recommendation.id)
        refreshRecommendations()
        Task { try? await store.save(feedback: entry) }
    }

    func snooze(_ recommendation: Recommendation, days: Int = 7) {
        snoozedRecommendationUntil[recommendation.id] = Date.now.addingTimeInterval(Double(days) * 86_400).timeIntervalSince1970
        refreshRecommendations()
    }

    func restoreDismissedRecommendations() {
        dismissedRecommendationIDs.removeAll(); refreshRecommendations()
        snoozedRecommendationUntil.removeAll(); refreshRecommendations()
    }

    func addFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = true; panel.prompt = "Monitor"
        if panel.runModal() == .OK { extraRoots.append(contentsOf: panel.urls.filter { !extraRoots.contains($0) }); scan() }
    }

    func removeFolder(_ url: URL) {
        extraRoots.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        scan()
    }

    func reveal(_ item: ScannedItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
    func quickLook(_ item: ScannedItem) { quickLookController.show(item.url) }

    func localExplanation(for item: ScannedItem) -> FileUseExplanation {
        FileUseExplainer.explain(item)
    }

    func explanation(for item: ScannedItem) -> FileUseExplanation {
        aiExplanations[item.id] ?? localExplanation(for: item)
    }

    func isExplaining(_ item: ScannedItem) -> Bool { isExplainingItemIDs.contains(item.id) }

    func saveAIAPIKey(_ key: String) {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            aiExplanationError = "Paste an API key before saving it."
            return
        }
        do {
            try KeychainSecretStore.saveAPIKey(cleaned)
            hasAIAPIKey = true
            aiExplanationError = nil
        } catch {
            aiExplanationError = error.localizedDescription
        }
    }

    func removeAIAPIKey() {
        KeychainSecretStore.deleteAPIKey()
        hasAIAPIKey = false
        aiExplanations.removeAll()
    }

    func requestAIExplanation(for item: ScannedItem) {
        guard aiExplanationsEnabled else {
            aiExplanationError = "AI explanations are off. Turn them on in Settings first."
            return
        }
        guard let apiKey = KeychainSecretStore.loadAPIKey() else {
            aiExplanationError = "Add an OpenAI API key in Settings before asking for an AI second opinion."
            return
        }
        guard !isExplaining(item) else { return }
        let local = localExplanation(for: item)
        let metadata = AIFileExplanationInput(item: item, localExplanation: local)
        isExplainingItemIDs.insert(item.id)
        aiExplanationError = nil
        Task {
            do {
                let explanation = try await OpenAIFileExplainer.explain(metadata, apiKey: apiKey, model: aiModel)
                aiExplanations[item.id] = FileUseExplanation(id: item.id, source: .ai,
                    headline: explanation.headline, summary: explanation.summary,
                    confidence: explanation.confidence, evidence: explanation.evidence,
                    caution: explanation.caution)
            } catch {
                aiExplanationError = error.localizedDescription
            }
            isExplainingItemIDs.remove(item.id)
        }
    }

    func moveToTrash(_ recommendation: Recommendation) {
        guard trustMode == .advisor, recommendation.kind != .cloudLocalCopy else { return }
        let before = currentDiskFreeSpace()
        var moved = 0
        for item in recommendation.affectedItems {
            do { _ = try FileManager.default.trashItem(at: item.url, resultingItemURL: nil); moved += 1 }
            catch { errorMessage = "Could not move \(item.url.lastPathComponent) to Trash: \(error.localizedDescription)" }
        }
        let record = ActionRecord(id: UUID(), performedAt: .now, title: recommendation.title,
            expectedBytes: recommendation.recoveryBytes, recoveredBytes: 0, itemCount: moved,
            result: moved == recommendation.affectedItems.count ? "Moved to Trash" : "Some files moved to Trash",
            verificationStatus: moved == 0 ? .failed : .awaitingTrash,
            freeSpaceBefore: before,
            verificationMessage: moved == 0
                ? "No files were moved. Review the error and try again."
                : "Empty Trash when you are ready, then ask Headroom to check the result.",
            affectedPaths: recommendation.affectedItems.map(\.url.path))
        actions.insert(record, at: 0)
        Task { try? await store.save(action: record) }
        selectedRecommendation = nil
        scan()
    }

    func evictCloudCopies(_ recommendation: Recommendation) {
        guard trustMode == .advisor, recommendation.kind == .cloudLocalCopy else { return }
        Task { await performCloudEviction(recommendation) }
    }

    private func performCloudEviction(_ recommendation: Recommendation) async {
        let before = currentDiskFreeSpace()
        var evicted = 0
        for item in recommendation.affectedItems {
            do { try FileManager.default.evictUbiquitousItem(at: item.url); evicted += 1 }
            catch { errorMessage = "Could not remove the local download for \(item.url.lastPathComponent): \(error.localizedDescription)" }
        }
        var measuredFree = before
        for _ in 0..<6 {
            try? await Task.sleep(for: .seconds(1))
            measuredFree = max(measuredFree, currentDiskFreeSpace())
        }
        let recovered = max(0, measuredFree - before)
        let completedAll = evicted == recommendation.affectedItems.count
        let status: ActionVerificationStatus = evicted == 0 ? .failed
            : (recovered == 0 ? .verifying : (completedAll ? .verified : .partial))
        let record = ActionRecord(performedAt: .now, title: recommendation.title,
            expectedBytes: recommendation.recoveryBytes, recoveredBytes: recovered,
            itemCount: evicted, result: completedAll ? "Local downloads removed" : "Some local downloads removed",
            verificationStatus: status, freeSpaceBefore: before,
            verificationMessage: recovered > 0
                ? "Headroom observed \(StorageFormatting.bytes(recovered)) more free space after removing the downloads."
                : "The removal request completed, but macOS has not reported additional free space yet.",
            affectedPaths: recommendation.affectedItems.map(\.url.path), completedAt: .now)
        actions.insert(record, at: 0); Task { try? await store.save(action: record) }
        selectedRecommendation = nil; scan()
    }

    func verify(_ action: ActionRecord) {
        guard [.awaitingTrash, .verifying].contains(action.effectiveVerificationStatus),
              let before = action.freeSpaceBefore,
              let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        let recovered = max(0, currentDiskFreeSpace() - before)
        let meaningful = recovered >= 1_000_000
        let nearExpected = action.expectedBytes == 0 || recovered >= Int64(Double(action.expectedBytes) * 0.8)
        let status: ActionVerificationStatus = !meaningful
            ? action.effectiveVerificationStatus
            : (nearExpected ? .verified : .partial)
        let message = meaningful
            ? "Headroom observed \(StorageFormatting.bytes(recovered)) more free space since this cleanup."
            : (action.effectiveVerificationStatus == .awaitingTrash
               ? "No additional free space is visible yet. Make sure Trash is empty, then check again."
               : "macOS has not reported additional free space yet. You can check again in a moment.")
        actions[index] = action.verified(with: recovered, status: status, message: message)
        Task { try? await store.save(actions: actions) }
        scan()
    }

    func protect(_ item: ScannedItem) {
        protectedPaths.insert(item.url.path)
        refreshRecommendations()
    }

    func protect(_ recommendation: Recommendation) {
        protectedPaths.formUnion(recommendation.affectedItems.map { $0.url.path })
        refreshRecommendations()
    }

    func unprotect(_ path: String) {
        protectedPaths.remove(path)
        refreshRecommendations()
    }

    func toggleProtectedFileType(_ type: String) {
        if protectedFileTypes.contains(type) { protectedFileTypes.remove(type) }
        else { protectedFileTypes.insert(type) }
        refreshRecommendations()
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Headroom Diagnostics.json"
        panel.allowedContentTypes = [.json]
        panel.prompt = "Export"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let snapshot = current
        var report: [String: Any] = [
            "createdAt": ISO8601DateFormatter().string(from: .now),
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "snapshotCount": snapshots.count,
            "actionCount": actions.count,
            "feedbackCount": feedback.count,
            "recommendationKinds": Dictionary(grouping: recommendations, by: { $0.kind.rawValue }).mapValues(\.count),
            "actionStatuses": Dictionary(grouping: actions, by: { $0.effectiveVerificationStatus.rawValue }).mapValues(\.count)
        ]
        if let snapshot {
            let latestScan: [String: Any] = [
                "capturedAt": ISO8601DateFormatter().string(from: snapshot.capturedAt),
                "durationSeconds": snapshot.scanDuration ?? 0,
                "scannedBytes": snapshot.scannedBytes,
                "scannedItemCount": snapshot.scannedItemCount,
                "inaccessibleLocationCount": snapshot.inaccessiblePaths.count,
                "deduplicatedHardLinks": snapshot.deduplicatedHardLinks ?? 0,
                "accountingNotes": snapshot.accountingNotes ?? []
            ]
            report["latestScan"] = latestScan
        }
        if includePathsInDiagnostics {
            report["inaccessiblePaths"] = snapshot?.inaccessiblePaths ?? []
            report["actionPaths"] = actions.flatMap { $0.affectedPaths ?? [] }
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Could not export diagnostics: \(error.localizedDescription)"
        }
    }

    private func currentDiskFreeSpace() -> Int64 {
        let values = try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    private func restartFileMonitoring() {
        guard hasCompletedOnboarding else { return }
        if fileSystemMonitor == nil {
            fileSystemMonitor = FileSystemMonitor { [weak self] paths in
                Task { @MainActor in self?.scheduleEventReconciliation(paths: paths) }
            }
        }
        fileSystemMonitor?.start(paths: StorageScanner.defaultRoots() + extraRoots)
    }

    private func scheduleEventReconciliation(paths: [String]) {
        pendingChangedPaths.formUnion(paths)
        eventReconciliationTask?.cancel()
        eventReconciliationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            let paths = Array(self.pendingChangedPaths)
            self.pendingChangedPaths.removeAll()
            self.beginScan(changedPaths: paths)
        }
    }
}
