import SwiftUI
import HeadroomCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isSidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                SidebarView()
                    .frame(width: 230)
                Divider()
            }

            destinationView
                .id(model.destination)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .background(Palette.canvas)
                .tint(Palette.mint)
        }
        .navigationTitle("Headroom")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Label(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.leading")
                }
                .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
            }
            ToolbarItemGroup {
                Button(action: model.addFolder) { Label("Add a folder", systemImage: "folder.badge.plus") }
                Button(action: model.scan) { Label("Check storage", systemImage: "arrow.clockwise") }.disabled(model.isScanning)
            }
        }
        .sheet(item: $model.selectedRecommendation) { RecommendationDetailView(recommendation: $0) }
        .sheet(isPresented: Binding(get: { !model.hasCompletedOnboarding }, set: { _ in })) { OnboardingView().interactiveDismissDisabled() }
        .alert("Headroom couldn’t finish that", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }), presenting: model.errorMessage) { _ in
            Button("OK") { model.errorMessage = nil }
        } message: { Text($0) }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch model.destination {
        case .home: DashboardView()
        case .actions: ActionCenterView()
        case .changes: ChangesView()
        case .explore: ExploreView()
        case .history: HistoryView()
        case .permissions: PermissionsView()
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ForEach(AppModel.Destination.allCases) { item in
                    Button {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            model.destination = item
                        }
                    } label: {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.body.weight(.medium))
                            .foregroundStyle(model.destination == item ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                    .frame(height: 40)
                            .background {
                                if model.destination == item {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Palette.mint.opacity(0.14))
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.rawValue)
                    .accessibilityHint("Opens \(item.rawValue)")
                    .accessibilityAddTraits(model.destination == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)

            Spacer(minLength: 16)
            Divider()
            ScanStatusView()
                .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .tint(Palette.mint)
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "gauge.with.dots.needle.50percent").font(.system(size: 34)).foregroundStyle(Palette.mint)
                VStack(alignment: .leading, spacing: 10) {
                    Text("See what is filling your Mac—and make space safely.").font(.system(size: 34, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                    Text("Headroom turns storage into a few clear choices. You review every file before anything changes.").font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Label("Everything stays on this Mac", systemImage: "lock.fill").font(.headline).foregroundStyle(Palette.mint)
                Text("Headroom looks at file names, sizes, locations, and dates. It never uploads your file list or file contents.").font(.callout).foregroundStyle(.secondary)
            }
            .padding(34).frame(width: 390).background(LinearGradient(colors: [Palette.mintSoft, Palette.ink], startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) { Text("Here’s what Headroom will do").font(.title2.weight(.semibold)); Text("macOS may ask before Headroom checks folders such as Downloads.").foregroundStyle(.secondary) }
                onboardingRow(icon: "externaldrive", title: "Show what is using space", detail: "See clear groups such as videos, downloads, app files, and documents.")
                onboardingRow(icon: "shield.checkered", title: "Keep a safety cushion", detail: "Headroom warns you before your Mac gets uncomfortably full.")
                onboardingRow(icon: "sparkles", title: "Suggest safe ways to make room", detail: "Every suggestion explains what will happen and how to undo it.")
                Spacer()
                HStack { Text("Nothing changes unless you review and approve it.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Check my storage") { model.completeOnboarding() }.buttonStyle(.borderedProminent).controlSize(.large) }
            }.padding(34)
        }.frame(width: 820, height: 500)
    }

    private func onboardingRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Palette.mint).frame(width: 38, height: 38).background(Palette.mint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.callout).foregroundStyle(.secondary) }
        }
    }
}

private struct ScanStatusView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Image(systemName: model.isScanning ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill").foregroundStyle(Palette.mint); Text(friendlyPhase).font(.caption.weight(.medium)).lineLimit(1); Spacer() }
            if model.isScanning { ProgressView(value: model.scanFraction).controlSize(.small).tint(Palette.mint) }
            Text(model.isScanning ? "\(StorageFormatting.bytes(model.scannedBytes)) · \(model.scannedItems.formatted()) items" : "Private and local to this Mac")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var friendlyPhase: String {
        model.scanPhase
            .replacingOccurrences(of: "Scanning", with: "Checking")
            .replacingOccurrences(of: "Finished", with: "Checked")
            .replacingOccurrences(of: "Up to date", with: "Ready")
    }
}
