import XCTest
@testable import SimpleNetworkCheck

final class SimpleNetworkCheckTests: XCTestCase {
    func testParseWiFiDevice() {
        let sample = """
        Hardware Port: Wi-Fi
        Device: en0
        Ethernet Address: aa:bb:cc:dd:ee:ff
        """

        XCTAssertEqual(parseWiFiDevice(from: sample), "en0")
    }

    func testParseWiFiDeviceSupportsAirPortLabel() {
        let sample = """
        Hardware Port: AirPort
        Device: en1
        Ethernet Address: aa:bb:cc:dd:ee:ff
        """

        XCTAssertEqual(parseWiFiDevice(from: sample), "en1")
    }

    func testParseWiFiPower() {
        XCTAssertEqual(parseWiFiPower(from: "Wi-Fi Power (en0): On"), true)
        XCTAssertEqual(parseWiFiPower(from: "Wi-Fi Power (en0): Off"), false)
        XCTAssertNil(parseWiFiPower(from: "unexpected"))
    }

    func testParseAirportInfo() {
        let sample = """
             agrCtlRSSI: -62
             SSID: MyHomeNet
             BSSID: aa:bb:cc:dd:ee:ff
             AirPort: On
        """

        let info = parseAirportInfo(from: sample)
        XCTAssertEqual(info.ssid, "MyHomeNet")
        XCTAssertEqual(info.powerOn, true)
    }

    func testParseGateway() {
        let sample = """
        route to: default
        gateway: 192.168.1.1
        interface: en0
        """

        XCTAssertEqual(parseGateway(from: sample), "192.168.1.1")
    }

    func testParseRSSI() {
        let sample = """
            agrCtlRSSI: -64
            agrCtlNoise: -90
        """

        XCTAssertEqual(parseRSSI(from: sample), -64)
    }

    func testRunnerRetriesUnknownAndThenPasses() async {
        let check = FlakyCheck()
        let runner = DiagnosticsRunner(checks: [check], timeoutSeconds: 1, retries: 1)
        let context = DiagnosticsContext(
            commandRunner: MockCommandRunner(),
            httpChecker: MockHTTPChecker(),
            wifiInfoProvider: MockWiFiInfoProvider(),
            state: DiagnosticState()
        )

        let results = await runner.runAll(context: context) { _, _, _ in }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.status, .pass)
    }

    func testSupportReportContainsSummaryFields() {
        let snapshot = DiagnosticsSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            overallStatus: .warn,
            wifiInterface: "en0",
            ssid: "HomeWiFi",
            localIP: "192.168.1.15",
            gateway: "192.168.1.1",
            macOSVersion: "macOS Test",
            results: [
                CheckResult(
                    id: "dns",
                    title: "DNS Resolution",
                    status: .warn,
                    headline: "DNS is unstable",
                    explanation: "Some DNS lookups work, but not all.",
                    recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
                    technicalDetails: "example detail"
                )
            ]
        )

        let report = SupportReportBuilder().build(snapshot: snapshot)

        XCTAssertTrue(report.contains("Simple Network Check Report"))
        XCTAssertTrue(report.contains("Overall: WARN"))
        XCTAssertTrue(report.contains("SSID: HomeWiFi"))
        XCTAssertTrue(report.contains("DNS Resolution"))
    }
}

private actor AttemptCounter {
    private(set) var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

private struct FlakyCheck: DiagnosticCheck {
    let id = "flaky"
    let title = "Flaky"
    private let counter = AttemptCounter()

    func run(context: DiagnosticsContext) async -> CheckResult {
        let attempt = await counter.increment()
        if attempt == 1 {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Unknown",
                explanation: "Retry me",
                recommendedAction: RemediationAction(label: "Retry", kind: .none),
                technicalDetails: "attempt 1"
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .pass,
            headline: "Passed",
            explanation: "Retry worked",
            recommendedAction: RemediationAction(label: "None", kind: .none),
            technicalDetails: "attempt 2"
        )
    }
}

private struct MockCommandRunner: CommandRunning {
    func run(_ command: String, _ arguments: [String]) async -> CommandResult {
        CommandResult(status: 0, stdout: "", stderr: "")
    }
}

private struct MockHTTPChecker: HTTPChecking {
    func check(url: URL, timeout: TimeInterval) async -> Bool {
        true
    }
}

private struct MockWiFiInfoProvider: WiFiInfoProviding {
    func currentInfo() -> WiFiInfo? {
        nil
    }
}
