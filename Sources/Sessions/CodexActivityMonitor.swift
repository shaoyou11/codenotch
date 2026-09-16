import AppKit
import Combine
import Foundation

/// The small, stable part of a Codex rollout that is useful for activity.
///
/// `item_completed` is intentionally ignored: commands and other child items
/// emit it too. A turn is complete only after Codex writes `task_complete`.
struct CodexRolloutActivity {
    enum State: Equatable {
        case busy
        case success
    }

    // Read backwards until the latest lifecycle event. Large tool outputs and
    // old turns do not need JSON decoding just to decide whether Codex is busy.
    static func state(from url: URL, chunkSize: Int = 65_536) -> State? {
        guard chunkSize > 0, let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        guard var offset = try? file.seekToEnd() else { return nil }
        var partial = Data()
        while offset > 0 {
            let count = Int(min(offset, UInt64(chunkSize)))
            offset -= UInt64(count)
            guard (try? file.seek(toOffset: offset)) != nil,
                  var block = try? file.read(upToCount: count) else { return nil }
            block.append(partial)
            let lines = block.split(separator: 10, omittingEmptySubsequences: false)
            partial = offset > 0 ? Data(lines[0]) : Data()
            let complete = offset > 0 ? lines.dropFirst() : lines[...]
            for line in complete.reversed() {
                guard let text = String(data: line, encoding: .utf8),
                      text.contains("event_msg"),
                      let object = try? JSONSerialization.jsonObject(with: Data(line)),
                      let record = object as? [String: Any],
                      record["type"] as? String == "event_msg",
                      let payload = record["payload"] as? [String: Any],
                      let type = payload["type"] as? String else { continue }
                switch type {
                case "task_started": return .busy
                case "task_complete": return .success
                case "turn_aborted": return nil
                default: continue
                }
            }
        }
        return nil
    }

}

/// Reports whether Codex is mid-turn.
///
/// Codex does not publish a live status field, but its rollout includes
/// lifecycle events. `task_started` and `task_complete` are used when present;
/// the file's recent modification time remains the activity fallback.
///
/// **That is a heuristic, and it is labelled as one.** It cannot tell a turn
/// that is thinking from one that finished a second ago, so it errs short: the
/// ring stops spinning `staleAfter` seconds after the last write rather than
/// claiming activity it cannot see. A stale rollout is deliberately not
/// converted into `.success` or `.idle`, because inactivity is not evidence
/// that a Codex turn completed — a long-running command can be quiet too.
/// If Codex grows a real status field this should be replaced by it.
@MainActor
final class CodexActivityMonitor: ObservableObject, AgentActivityMonitor {
    @Published private(set) var sessions: [AgentSession] = []
    var sessionsPublisher: AnyPublisher<[AgentSession], Never> { $sessions.eraseToAnyPublisher() }

    private let stateStore: URL
    private let desktopStore: URL
    private let profile: CodexProfile
    private let interval: TimeInterval
    /// How long after the last write a turn is still considered in flight.
    private let staleAfter: TimeInterval
    private var timer: Timer?
    private var scanInFlight = false
    private var generation = 0
    private let scan: () -> [AgentSession]
    private let scanQueue = DispatchQueue(label: "CodenotchT.codex-activity", qos: .utility)

    init(
        profile: CodexProfile = .default(),
        stateStore: URL? = nil,
        desktopStore: URL? = nil,
        interval: TimeInterval = 2,
        staleAfter: TimeInterval = 8,
        scan: (() -> [AgentSession])? = nil
    ) {
        self.profile = profile
        self.stateStore = stateStore ?? profile.stateURL
        self.desktopStore = desktopStore ?? profile.desktopStoreURL
        self.interval = interval
        self.staleAfter = staleAfter
        let state = stateStore ?? profile.stateURL
        let desktop = desktopStore ?? profile.desktopStoreURL
        self.scan = scan ?? {
            Self.read(stateStore: state, desktopStore: desktop,
                      staleAfter: staleAfter, profile: profile)
        }
    }

    func start() {
        guard timer == nil else { return }
        generation += 1
        rescan()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.rescan() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        generation += 1
    }

    private func rescan() {
        guard !scanInFlight else { return }
        scanInFlight = true
        let currentGeneration = generation
        let scan = scan
        scanQueue.async { [weak self] in
            let found = scan()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scanInFlight = false
                guard self.generation == currentGeneration, self.timer != nil else { return }
                if found != self.sessions { self.sessions = found }
            }
        }
    }

    nonisolated static func read(stateStore: URL, desktopStore: URL,
                     staleAfter: TimeInterval, now: Date = Date(),
                     profile: CodexProfile = .default()) -> [AgentSession] {
        // Both surfaces, because "Codex" is two programs that record their work
        // in different places: the CLI and the VS Code extension append to a
        // rollout, and the desktop app writes to its own catalogue. Whichever
        // moved last is the one that is working.
        var candidates: [(id: String, name: String, at: Date, state: AgentSession.State)] = []

        if let rollout = CodexStore.newestRollout(in: stateStore),
           let modified = (try? FileManager.default
               .attributesOfItem(atPath: rollout.path))?[.modificationDate] as? Date {
            let state: AgentSession.State
            switch CodexRolloutActivity.state(from: rollout) {
            case .success: state = .success
            case .busy, .none: state = .busy
            }
            candidates.append((id: "\(profile.id).\(rollout.lastPathComponent)",
                               name: profile.displayName, at: modified, state: state))
        }
        if let desktop = CodexStore.newestDesktopThread(in: desktopStore) {
            candidates.append((id: "\(profile.id).desktop", name: desktop.title,
                               at: desktop.updatedAt, state: .busy))
        }

        guard let newest = candidates.max(by: { $0.at < $1.at }),
              let session = session(id: newest.id, name: newest.name,
                                    modified: newest.at, state: newest.state,
                                    staleAfter: staleAfter, now: now)
        else { return [] }
        return [session]
    }

    /// Only work recorded within the window counts. Anything older is a
    /// finished turn, and reporting it as work in progress would be a guess
    /// dressed as a fact.
    nonisolated static func session(
        id: String, name: String, modified: Date,
        state: AgentSession.State = .busy,
        staleAfter: TimeInterval, now: Date
    ) -> AgentSession? {
        guard now.timeIntervalSince(modified) <= staleAfter else { return nil }

        return AgentSession(
            id: id,
            name: name,
            detail: state == .success ? L10n.t("Complete") : L10n.t("Working"),
            state: state,
            waitingFor: nil,
            since: modified
        )
    }
}
