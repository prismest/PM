import Foundation
import Combine
import AppKit

@MainActor
public final class MCPServerManager: ObservableObject {
    public static let shared = MCPServerManager()

    @Published public var isRunning: Bool = false
    @Published public var port: Int = 8765
    @Published public var isStarting: Bool = false

    private var process: Process?
    private var statusTimer: Timer?
    private let statusFileURL: URL
    private let pidFileURL: URL
    private let dotWaanDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Waan", isDirectory: true)
        self.statusFileURL = dir.appendingPathComponent("mcp_status.json")
        self.pidFileURL = dir.appendingPathComponent("mcp.pid")

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.dotWaanDir = homeDir.appendingPathComponent(".waan")

        checkStatus()
        syncScriptToDotWaan()

        let userEnabled = Foundation.UserDefaults.standard.object(forKey: "mcpServerEnabled") as? Bool ?? true
        if userEnabled && !isRunning {
            start()
        }

        Foundation.NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: Foundation.OperationQueue.main
        ) { [weak self] (_: Notification) in
            Task { @MainActor [weak self] in
                self?.stopProcessOnly()
            }
        }

        statusTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkStatus()
            }
        }
    }

    public func resolveScriptPath() -> String {
        if let resPath = Foundation.Bundle.main.path(forResource: "mcp_server", ofType: "py"),
           FileManager.default.fileExists(atPath: resPath) {
            return resPath
        }
        return dotWaanDir.appendingPathComponent("mcp_server.py").path
    }

    private func syncScriptToDotWaan() {
        let target = dotWaanDir.appendingPathComponent("mcp_server.py")
        let sourcePath = resolveScriptPath()
        guard FileManager.default.fileExists(atPath: sourcePath) else { return }

        if sourcePath != target.path {
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(atPath: sourcePath, toPath: target.path)
        }
    }

    public func checkStatus() {
        if let proc = process, proc.isRunning {
            self.isRunning = true
            return
        }

        if let pidStr = try? String(contentsOf: pidFileURL, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if kill(pid, 0) == 0 {
                self.isRunning = true
                return
            }
        }

        self.isRunning = false
    }

    public func start() {
        guard !isStarting else { return }
        if isRunning { return }

        isStarting = true

        let script = resolveScriptPath()
        syncScriptToDotWaan()

        guard FileManager.default.fileExists(atPath: script) else {
            isStarting = false
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.arguments = [script, "--port", String(port)]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.isStarting = false
                self?.process = nil
            }
        }

        do {
            try proc.run()
            self.process = proc
            Foundation.UserDefaults.standard.set(true, forKey: "mcpServerEnabled")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isStarting = false
                self?.checkStatus()
            }
        } catch {
            isStarting = false
            process = nil
        }
    }

    public func stop() {
        Foundation.UserDefaults.standard.set(false, forKey: "mcpServerEnabled")
        stopProcessOnly()
    }

    private func stopProcessOnly() {
        if let proc = process, proc.isRunning {
            proc.terminate()
            process = nil
        }

        if let pidStr = try? String(contentsOf: pidFileURL, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
            try? FileManager.default.removeItem(at: pidFileURL)
        }

        let disabledJson = """
        {
          "enabled": false,
          "running": false,
          "port": \(port),
          "pid": null
        }
        """
        try? disabledJson.write(to: statusFileURL, atomically: true, encoding: .utf8)

        isRunning = false
        isStarting = false
    }
}
