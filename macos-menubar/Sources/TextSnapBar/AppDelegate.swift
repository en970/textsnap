import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum IconState { case idle, processing, success, failure }

    private var statusItem: NSStatusItem!
    private var hud: HUDWindowController?
    private var pulseTimer: Timer?
    private var isBusy = false
    private var resolvedTextsnapPath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(.idle)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
    }

    @objc private func statusItemClicked() {
        guard !isBusy else { return }
        beginCaptureFlow()
    }

    // MARK: - Capture flow

    private func beginCaptureFlow() {
        isBusy = true
        let changeCountBefore = NSPasteboard.general.changeCount

        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-i", "-c"]

        capture.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let changed = NSPasteboard.general.changeCount != changeCountBefore
                guard changed else {
                    self.isBusy = false
                    self.updateIcon(.idle)
                    return
                }
                self.beginProcessing()
            }
        }

        do {
            try capture.run()
        } catch {
            isBusy = false
            updateIcon(.idle)
            notify(title: "textsnap", subtitle: nil, message: "Couldn't start screen capture.")
        }
    }

    private func beginProcessing() {
        updateIcon(.processing)
        startPulse()
        showHUD(state: .processing)

        guard let path = resolveTextsnapExecutable() else {
            finishProcessing(success: false, message: "textsnap command not found on PATH.")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = []
        let stderrPipe = Pipe()
        proc.standardError = stderrPipe
        proc.standardOutput = Pipe()

        proc.terminationHandler = { [weak self] p in
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                self?.finishProcessing(success: p.terminationStatus == 0, message: errText)
            }
        }

        do {
            try proc.run()
        } catch {
            finishProcessing(success: false, message: "\(error)")
        }
    }

    private func finishProcessing(success: Bool, message: String) {
        stopPulse()
        isBusy = false

        if success {
            updateIcon(.success)
            showHUD(state: .success)
            let preview = NSPasteboard.general.string(forType: .string).map(oneLinePreview)
            notify(title: "textsnap", subtitle: preview, message: "Copied to clipboard")
        } else {
            updateIcon(.failure)
            showHUD(state: .failure)
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            notify(title: "textsnap", subtitle: nil, message: trimmed.isEmpty ? "Recognition failed." : trimmed)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.updateIcon(.idle)
            self?.hud?.hide()
        }
    }

    private func oneLinePreview(_ s: String) -> String {
        let flattened = s.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > 64 else { return flattened }
        let idx = flattened.index(flattened.startIndex, offsetBy: 64)
        return String(flattened[..<idx]) + "…"
    }

    // MARK: - Status bar icon

    private func updateIcon(_ state: IconState) {
        let symbolName: String
        switch state {
        case .idle: symbolName = "viewfinder"
        case .processing: symbolName = "viewfinder.circle.fill"
        case .success: symbolName = "checkmark.circle.fill"
        case .failure: symbolName = "exclamationmark.triangle.fill"
        }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "textsnap")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func startPulse() {
        var faded = false
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            faded.toggle()
            self?.statusItem.button?.alphaValue = faded ? 0.4 : 1.0
        }
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        statusItem.button?.alphaValue = 1.0
    }

    // MARK: - HUD

    private func showHUD(state: HUDContentView.HUDState) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        if hud == nil {
            hud = HUDWindowController()
        }
        let anchorFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        hud?.show(state: state, anchorFrame: anchorFrame)
    }

    // MARK: - Resolving the textsnap executable

    private func resolveTextsnapExecutable() -> String? {
        if let cached = resolvedTextsnapPath { return cached }

        let candidates = [
            "/Users/\(NSUserName())/pyenv/bin/textsnap",
            "/opt/homebrew/bin/textsnap",
            "/usr/local/bin/textsnap",
            NSHomeDirectory() + "/.local/bin/textsnap",
            NSHomeDirectory() + "/.pyenv/shims/textsnap",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            resolvedTextsnapPath = candidate
            return candidate
        }

        // Fallback: resolve through the user's login shell so pyenv/asdf/venv shims on PATH are found too.
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/bin/zsh")
        which.arguments = ["-l", "-i", "-c", "command -v textsnap"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !out.isEmpty, FileManager.default.isExecutableFile(atPath: out) {
                resolvedTextsnapPath = out
                return out
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Notifications

    private func notify(title: String, subtitle: String?, message: String) {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        var script = "display notification \"\(esc(message))\" with title \"\(esc(title))\""
        if let subtitle, !subtitle.isEmpty {
            script += " subtitle \"\(esc(subtitle))\""
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
    }
}
