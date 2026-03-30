import Foundation

protocol DiagnosticCheck: Sendable {
    var id: String { get }
    var title: String { get }
    func run(context: DiagnosticsContext) async -> CheckResult
}

protocol CommandRunning: Sendable {
    func run(_ command: String, _ arguments: [String]) async -> CommandResult
}

struct CommandResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

protocol HTTPChecking: Sendable {
    func check(url: URL, timeout: TimeInterval) async -> Bool
}

struct WiFiInfo: Sendable {
    let interface: String?
    let ssid: String?
    let rssi: Int?
    let powerOn: Bool?
}

protocol WiFiInfoProviding: Sendable {
    func currentInfo() -> WiFiInfo?
}

struct NullWiFiInfoProvider: WiFiInfoProviding {
    func currentInfo() -> WiFiInfo? {
        nil
    }
}

struct DiagnosticsContext: Sendable {
    let commandRunner: CommandRunning
    let httpChecker: HTTPChecking
    let wifiInfoProvider: WiFiInfoProviding
    let state: DiagnosticState
}

struct DiagnosticsRunner: Sendable {
    let checks: [any DiagnosticCheck]
    let timeoutSeconds: TimeInterval
    let retries: Int

    init(checks: [any DiagnosticCheck], timeoutSeconds: TimeInterval = 3, retries: Int = 1) {
        self.checks = checks
        self.timeoutSeconds = timeoutSeconds
        self.retries = retries
    }

    func runAll(
        context: DiagnosticsContext,
        onProgress: @Sendable (String, Int, Int) -> Void
    ) async -> [CheckResult] {
        var results: [CheckResult] = []

        for (index, check) in checks.enumerated() {
            onProgress(check.title, index + 1, checks.count)
            let result = await runSingle(check: check, context: context)
            results.append(result)
        }

        return results
    }

    private func runSingle(check: any DiagnosticCheck, context: DiagnosticsContext) async -> CheckResult {
        var attempt = 0
        var lastResult: CheckResult?

        while attempt <= retries {
            let result = await runWithTimeout(seconds: timeoutSeconds) {
                await check.run(context: context)
            }

            switch result {
            case .success(let checkResult):
                if checkResult.status == .unknown, attempt < retries {
                    lastResult = checkResult
                    attempt += 1
                    continue
                }
                return checkResult
            case .timeout:
                lastResult = CheckResult(
                    id: check.id,
                    title: check.title,
                    status: .unknown,
                    headline: "Timed out",
                    explanation: "This check took too long and may need to be retried.",
                    recommendedAction: RemediationAction(label: "Run checks again", kind: .none),
                    technicalDetails: "Timeout after \(Int(timeoutSeconds)) seconds"
                )
                attempt += 1
            }
        }

        return lastResult ?? CheckResult(
            id: check.id,
            title: check.title,
            status: .unknown,
            headline: "Unknown",
            explanation: "The diagnostic did not return a result.",
            recommendedAction: RemediationAction(label: "Run checks again", kind: .none),
            technicalDetails: "No result produced"
        )
    }
}

enum TimedResult<T: Sendable>: Sendable {
    case success(T)
    case timeout
}

func runWithTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T) async -> TimedResult<T> {
    await withTaskGroup(of: TimedResult<T>.self) { group in
        group.addTask {
            .success(await operation())
        }

        group.addTask {
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            return .timeout
        }

        let first = await group.next() ?? .timeout
        group.cancelAll()
        return first
    }
}
