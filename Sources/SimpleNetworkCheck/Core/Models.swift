import Foundation

enum CheckStatus: String, Codable, CaseIterable {
    case pass
    case warn
    case fail
    case unknown

    var rank: Int {
        switch self {
        case .pass: return 0
        case .warn: return 1
        case .fail: return 2
        case .unknown: return 1
        }
    }
}

enum RemediationActionKind: Codable, Equatable {
    case openNetworkSettings
    case toggleWiFi
    case showRenewDHCPGuide
    case copyTroubleshootingText
    case none
}

struct RemediationAction: Codable, Equatable {
    let label: String
    let kind: RemediationActionKind
}

struct CheckResult: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let status: CheckStatus
    let headline: String
    let explanation: String
    let recommendedAction: RemediationAction
    let technicalDetails: String
}

struct DiagnosticsSnapshot: Codable, Equatable {
    let timestamp: Date
    let overallStatus: CheckStatus
    let wifiInterface: String?
    let ssid: String?
    let localIP: String?
    let gateway: String?
    let macOSVersion: String
    let results: [CheckResult]
}

final class DiagnosticState: @unchecked Sendable {
    var wifiInterface: String?
    var ssid: String?
    var localIP: String?
    var gateway: String?
}
