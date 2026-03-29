import Foundation

struct SupportReportBuilder {
    func build(snapshot: DiagnosticsSnapshot) -> String {
        var lines: [String] = []

        lines.append("Simple Network Check Report")
        lines.append("Timestamp: \(snapshot.timestamp.formatted(date: .abbreviated, time: .standard))")
        lines.append("macOS: \(snapshot.macOSVersion)")
        lines.append("Overall: \(snapshot.overallStatus.rawValue.uppercased())")
        lines.append("Wi-Fi interface: \(snapshot.wifiInterface ?? "unknown")")
        lines.append("SSID: \(snapshot.ssid ?? "unknown")")
        lines.append("Local IP: \(snapshot.localIP ?? "unknown")")
        lines.append("Gateway: \(snapshot.gateway ?? "unknown")")
        lines.append("")

        for result in snapshot.results {
            lines.append("[\(result.status.rawValue.uppercased())] \(result.title): \(result.headline)")
            lines.append("- \(result.explanation)")
            lines.append("- Recommended action: \(result.recommendedAction.label)")
            if !result.technicalDetails.isEmpty {
                lines.append("- Details: \(result.technicalDetails.replacingOccurrences(of: "\n", with: " | "))")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    func buildJSON(snapshot: DiagnosticsSnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(snapshot) else {
            return "{\"error\":\"unable to encode report\"}"
        }

        return String(decoding: data, as: UTF8.self)
    }
}
