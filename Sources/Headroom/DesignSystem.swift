import SwiftUI
import HeadroomCore

enum Palette {
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.14)
    static let mint = Color(red: 0.23, green: 0.64, blue: 0.50)
    static let amber = Color(red: 0.91, green: 0.58, blue: 0.20)
    static let coral = Color(red: 0.86, green: 0.35, blue: 0.32)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let mintSoft = Color(red: 0.14, green: 0.30, blue: 0.25)
}

struct PageScrollView<Content: View>: View {
    private let topID = "page-top"
    @State private var scrollIdentity = UUID()
    @ViewBuilder let content: Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id(topID)
                content
            }
            .id(scrollIdentity)
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(topID, anchor: .top)
                }
            }
        }
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(20)
            .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.separator.opacity(0.45)))
            .shadow(color: .black.opacity(0.035), radius: 12, y: 5)
    }
}

struct PageHeader<Actions: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions
    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow).font(.caption.weight(.semibold)).foregroundStyle(Palette.mint)
                Text(title).font(.system(size: 30, weight: .semibold, design: .rounded))
                Text(subtitle).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            actions
        }
        .accessibilityElement(children: .contain)
    }
}

struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = Palette.mint
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.headline).foregroundStyle(color).frame(width: 34, height: 34)
                .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InlineEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
        }.frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}

struct SectionTitle: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5).background(color.opacity(0.11), in: Capsule())
    }
}

extension RiskLevel {
    var color: Color { self == .low ? Palette.mint : (self == .medium ? Palette.amber : Palette.coral) }
}

extension Confidence {
    var label: String { rawValue.capitalized + " confidence" }
}

extension FileExplanationConfidence {
    var color: Color {
        switch self {
        case .high: Palette.mint
        case .medium: Palette.amber
        case .low: .secondary
        }
    }
}

extension Recommendation {
    var friendlySafetyLabel: String {
        switch risk {
        case .low: "Safe to try"
        case .medium: "Review carefully"
        case .high: "Extra caution"
        }
    }

    var friendlyUndoLabel: String {
        if kind == .cloudLocalCopy { return "Downloads again when opened" }
        return reversible ? "Stays in Trash until you empty it" : "Cannot be undone"
    }

    var friendlyReason: String {
        switch kind {
        case .generatedData: "Your apps can recreate these files."
        case .oldInstaller: "These older downloads are usually used only once."
        case .duplicate: "An identical copy will remain on your Mac."
        case .cloudLocalCopy: "Headroom confirmed a copy remains in iCloud."
        case .largeRecentFile: "These files explain a meaningful part of recent growth."
        case .screenRecording: "These recordings are older and often safe to archive or remove."
        case .largeVideo: "These videos use a meaningful amount of storage and have not changed recently."
        }
    }

    var friendlyAction: String {
        switch kind {
        case .cloudLocalCopy: "Remove only the downloads from this Mac"
        default: "Move the selected files to Trash"
        }
    }
}

extension StorageGroup {
    var friendlyDescription: String {
        switch name.lowercased() {
        case "video", "movies": "Movies, recordings, and video exports"
        case "images", "pictures": "Photos, screenshots, and artwork"
        case "audio", "music": "Music, recordings, and sound files"
        case "documents": "Documents, PDFs, and notes"
        case "archives & installers", "downloads": "Installers, ZIP files, and downloads"
        case "source code": "Project and programming files"
        case "caches": "Temporary files created by apps"
        case "xcode": "Build files and developer tools"
        case "other": "Files that do not fit another group"
        default: "Files associated with \(name)"
        }
    }

    var friendlyIcon: String {
        switch name.lowercased() {
        case "video", "movies": "film"
        case "images", "pictures": "photo"
        case "audio", "music": "waveform"
        case "documents": "doc.text"
        case "archives & installers", "downloads": "arrow.down.circle"
        case "source code", "xcode": "hammer"
        case "caches": "clock.arrow.circlepath"
        default: "folder"
        }
    }
}
