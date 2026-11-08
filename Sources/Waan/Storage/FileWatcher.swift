import Foundation

public final class FileWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private let filePath: String
    private let onChange: () -> Void

    public init(filePath: String, onChange: @escaping () -> Void) {
        self.filePath = filePath
        self.onChange = onChange
        startWatching()
    }

    deinit {
        stopWatching()
    }

    public func startWatching() {
        stopWatching()

        fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onChange()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        self.source = source
        source.resume()
    }

    public func stopWatching() {
        if let s = source {
            s.cancel()
            source = nil
        }
    }
}

