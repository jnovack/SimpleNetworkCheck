import AppKit
import Foundation
import SwiftUI

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var progressText = ""
    @Published var results: [CheckResult] = []
    @Published var overallStatus: CheckStatus = .unknown
    @Published var reportText = ""
    @Published var reportJSON = ""
    @Published var lastRunDate: Date?

    private let state: DiagnosticState
    private let context: DiagnosticsContext
    private let runner: DiagnosticsRunner
    private let reportBuilder = SupportReportBuilder()

    init(
        commandRunner: CommandRunning = SystemCommandRunner(),
        httpChecker: HTTPChecking = URLSessionHTTPChecker(),
        checks: [any DiagnosticCheck] = defaultChecks()
    ) {
        let state = DiagnosticState()
        self.state = state
        self.context = DiagnosticsContext(commandRunner: commandRunner, httpChecker: httpChecker, state: state)
        self.runner = DiagnosticsRunner(checks: checks, timeoutSeconds: 3, retries: 1)
    }

    func runChecks() {
        isRunning = true
        progressText = "Preparing checks..."
        results = []
        reportText = ""
        reportJSON = ""
        overallStatus = .unknown
        clearState()

        Task {
            let checkResults = await runner.runAll(context: context) { [weak self] title, index, total in
                Task { @MainActor in
                    self?.progressText = "Running \(index)/\(total): \(title)"
                }
            }

            self.results = checkResults
            self.overallStatus = aggregateStatus(for: checkResults)
            self.lastRunDate = Date()
            self.progressText = "Done"
            self.isRunning = false

            let snapshot = DiagnosticsSnapshot(
                timestamp: lastRunDate ?? Date(),
                overallStatus: overallStatus,
                wifiInterface: state.wifiInterface,
                ssid: state.ssid,
                localIP: state.localIP,
                gateway: state.gateway,
                macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                results: checkResults
            )

            self.reportText = reportBuilder.build(snapshot: snapshot)
            self.reportJSON = reportBuilder.buildJSON(snapshot: snapshot)
        }
    }

    func performAction(for result: CheckResult) {
        switch result.recommendedAction.kind {
        case .openNetworkSettings:
            openNetworkSettings()
        case .toggleWiFi:
            toggleWiFi()
        case .showRenewDHCPGuide:
            copyDHCPGuide()
        case .copyTroubleshootingText:
            copyTroubleshootingGuide()
        case .none:
            break
        }
    }

    func copyReportToClipboard() {
        guard !reportText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText + "\n\nJSON:\n" + reportJSON, forType: .string)
    }

    private func clearState() {
        state.wifiInterface = nil
        state.ssid = nil
        state.localIP = nil
        state.gateway = nil
    }

    private func aggregateStatus(for results: [CheckResult]) -> CheckStatus {
        if results.contains(where: { $0.status == .fail }) {
            return .fail
        }
        if results.contains(where: { $0.status == .warn }) {
            return .warn
        }
        if results.allSatisfy({ $0.status == .pass }) {
            return .pass
        }
        return .unknown
    }

    private func openNetworkSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension"),
            URL(fileURLWithPath: "/System/Library/PreferencePanes/Network.prefPane")
        ].compactMap { $0 }

        for url in urls where NSWorkspace.shared.open(url) {
            return
        }
    }

    private func toggleWiFi() {
        guard let iface = state.wifiInterface else {
            copyTroubleshootingGuide()
            return
        }

        Task.detached {
            let runner = SystemCommandRunner()
            _ = await runner.run(Shell.networksetup, ["-setairportpower", iface, "off"])
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await runner.run(Shell.networksetup, ["-setairportpower", iface, "on"])
        }
    }

    private func copyDHCPGuide() {
        let text = """
        DHCP Renew Steps:
        1. Open System Settings > Network.
        2. Select Wi-Fi and click Details.
        3. Open TCP/IP tab.
        4. Click Renew DHCP Lease.
        5. Re-run Simple Network Check.
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyTroubleshootingGuide() {
        let text = """
        Quick Troubleshooting:
        1. Confirm Wi-Fi is turned on.
        2. Move closer to the router.
        3. Restart router and modem (unplug 30 seconds, plug back in).
        4. Wait 2 minutes, then run Simple Network Check again.
        5. If still failing, share the report with support.
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
