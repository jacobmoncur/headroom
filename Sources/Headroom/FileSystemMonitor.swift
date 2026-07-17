import CoreServices
import Foundation
import HeadroomCore

/// Watches the selected folders recursively. FSEvents coalesces noisy changes, and AppModel
/// applies a second debounce before reconciling the persisted storage snapshot.
final class FileSystemMonitor: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "dev.moncur.headroom.filesystem-events", qos: .utility)
    private let onChange: @Sendable ([String]) -> Void

    init(onChange: @escaping @Sendable ([String]) -> Void) {
        self.onChange = onChange
    }

    func start(paths: [URL]) {
        stop()
        let watchedPaths = StorageScanner.normalizedRoots(paths).map(\.path)
        guard !watchedPaths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, eventCount, eventPaths, flags, _ in
            guard eventCount > 0, let info else { return }
            let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(info).takeUnretainedValue()
            let pathsPointer = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
            let relevantPaths = (0..<eventCount).compactMap { index -> String? in
                let ignored = FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone |
                    kFSEventStreamEventFlagEventIdsWrapped)
                guard flags[index] & ignored == 0 else { return nil }
                return String(cString: pathsPointer[index])
            }
            if !relevantPaths.isEmpty { monitor.onChange(relevantPaths) }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            watchedPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagWatchRoot)
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
