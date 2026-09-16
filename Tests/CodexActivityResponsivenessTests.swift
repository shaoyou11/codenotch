import Combine
import XCTest
@testable import Codenotch

final class CodexActivityResponsivenessTests: XCTestCase {
    private func event(_ type: String) -> String {
        "{\"type\":\"event_msg\",\"payload\":{\"type\":\"\(type)\",\"note\":\"中文\"}}"
    }

    func testReverseReaderPreservesEventsAcrossByteBoundaries() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        for size in [1, 7, 31, 64, 65536] {
            let text = event("task_started") + "\n" + event("task_complete") + "\n{\"partial\":"
            try Data(text.utf8).write(to: url)
            XCTAssertEqual(CodexRolloutActivity.state(from: url, chunkSize: size), .success)
            try Data((text + "\n" + event("turn_aborted")).utf8).write(to: url)
            XCTAssertNil(CodexRolloutActivity.state(from: url, chunkSize: size))
        }
    }

    func testLifecycleBeforeLargeToolOutputIsStillFound() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let tool = "{\"type\":\"response_item\",\"text\":\"" + String(repeating: "x", count: 200_000) + "\"}"
        try Data((event("task_complete") + "\n" + tool + "\n").utf8).write(to: url)
        XCTAssertEqual(CodexRolloutActivity.state(from: url), .success)
        try Data((event("task_complete") + "\n" + tool + "\n" + event("task_started")).utf8).write(to: url)
        XCTAssertEqual(CodexRolloutActivity.state(from: url), .busy)
    }

    @MainActor
    func testSlowScanDoesNotBlockUIOrPublishAfterStop() async throws {
        let entered = expectation(description: "worker entered")
        entered.assertForOverFulfill = true
        let finished = expectation(description: "worker finished")
        let gate = DispatchSemaphore(value: 0)
        let monitor = CodexActivityMonitor(interval: 0.01, scan: {
            XCTAssertFalse(Thread.isMainThread, "Disk and JSON work must never run on the UI thread")
            entered.fulfill()
            _ = gate.wait(timeout: .now() + 3)
            finished.fulfill()
            return [AgentSession(id: "test", name: "test", detail: "", state: .busy,
                                 waitingFor: nil, since: Date())]
        })
        defer { gate.signal(); monitor.stop() }
        monitor.start()
        monitor.start()
        await fulfillment(of: [entered], timeout: 2)
        // Main-actor work remains schedulable while I/O is deliberately blocked;
        // timer ticks must not enqueue overlapping scans.
        try await Task.sleep(nanoseconds: 80_000_000)
        monitor.stop()
        gate.signal()
        await fulfillment(of: [finished], timeout: 2)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(monitor.sessions.isEmpty, "A disabled monitor must discard a late scan")
    }

    @MainActor
    func testBackgroundResultReachesMainThread() async {
        let published = expectation(description: "published")
        let monitor = CodexActivityMonitor(interval: 60, scan: {
            [AgentSession(id: "test", name: "test", detail: "", state: .success,
                          waitingFor: nil, since: Date())]
        })
        let subscription = monitor.$sessions.dropFirst().sink { sessions in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(sessions.first?.state, .success)
            published.fulfill()
        }
        monitor.start()
        await fulfillment(of: [published], timeout: 2)
        monitor.stop()
        withExtendedLifetime(subscription) {}
    }
}
