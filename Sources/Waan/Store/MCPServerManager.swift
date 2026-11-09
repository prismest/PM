import Foundation
import Combine
import AppKit

@MainActor
public final class MCPServerManager: ObservableObject {
    public static let shared = MCPServerManager()

    @Published public var isRunning: Bool = false
    @Published public var port: Int = 8765

    private var process: Process?
    private let statusFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Waan", isDirectory: true)
        self.statusFileURL = dir.appendingPathComponent("mcp_status.json")

        checkStatus()

        let userEnabled = Foundation.UserDefaults.standard.object(forKey: "mcpServerEnabled") as? Bool ?? true
        if userEnabled && !isRunning {
            start()
        }

        Foundation.NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopProcessOnly()
            }
        }
    }

    public func resolveScriptPath() -> String {
        if let resPath = Foundation.Bundle.main.path(forResource: "mcp_server", ofType: "py"),
           FileManager.default.fileExists(atPath: resPath) {
            return resPath
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".waan/mcp_server.py").path
    }

    public func checkStatus() {
        if let proc = process, proc.isRunning {
            self.isRunning = true
            return
        }

        if let data = try? Data(contentsOf: statusFileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pid = json["pid"] as? Int32,
           kill(pid, 0) == 0 {
            self.isRunning = true
            return
        }

        self.isRunning = false
    }

    public func start() {
        if isRunning { return }

        let script = resolveScriptPath()
        guard FileManager.default.fileExists(atPath: script) else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.currentDirectoryURL = statusFileURL.deletingLastPathComponent()
        proc.arguments = [script, "--port", String(port)]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.process = nil
            }
        }

        do {
            try proc.run()
            self.process = proc
            Foundation.UserDefaults.standard.set(true, forKey: "mcpServerEnabled")
            self.isRunning = true
        } catch {
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

        if let data = try? Data(contentsOf: statusFileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pid = json["pid"] as? Int32 {
            kill(pid, SIGTERM)
        }

        let disabledJson = "{\"enabled\":false,\"running\":false,\"port\":\(port),\"pid\":null}"
        try? disabledJson.write(to: statusFileURL, atomically: true, encoding: .utf8)

        isRunning = false
    }
}
