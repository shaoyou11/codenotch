import AppKit

/// Window geometry is available without capturing screen contents or requesting
/// Accessibility access. Covers native full-screen and borderless video windows.
@MainActor
enum FullscreenDetector {
    private static var checkedAt: TimeInterval = -1
    private static var frames: [CGRect] = []
    private static var queryInFlight = false

    static func covers(_ screen: NSScreen) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if now - checkedAt >= 0.3 && !queryInFlight {
            checkedAt = now
            queryInFlight = true
            DispatchQueue.global(qos: .utility).async {
                let result = readWindowFrames()
                Task { @MainActor in
                    frames = result
                    queryInFlight = false
                }
            }
        }
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return false }
        let bounds = CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
        return frames.contains { fillsScreen($0, screen: bounds) }
    }

    /// WindowServer IPC never runs on the mouse/animation thread.
    nonisolated private static func readWindowFrames() -> [CGRect] {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int,
                  pid != Int(ProcessInfo.processInfo.processIdentifier),
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any]
            else { return nil }
            return CGRect(dictionaryRepresentation: bounds as CFDictionary)
        }
    }

    nonisolated static func fillsScreen(_ window: CGRect, screen: CGRect) -> Bool {
        guard screen.width > 0, screen.height > 0 else { return false }
        return abs(window.minX - screen.minX) <= 2 && abs(window.minY - screen.minY) <= 2
            && abs(window.width - screen.width) <= 2 && abs(window.height - screen.height) <= 2
    }
}
