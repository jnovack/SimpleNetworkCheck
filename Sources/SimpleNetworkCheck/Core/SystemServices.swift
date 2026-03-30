import Foundation
import CoreWLAN

struct SystemCommandRunner: CommandRunning {
    func run(_ command: String, _ arguments: [String]) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                continuation.resume(returning: CommandResult(
                    status: -1,
                    stdout: "",
                    stderr: "Failed to run \(command): \(error.localizedDescription)"
                ))
                return
            }

            process.terminationHandler = { terminated in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(decoding: stdoutData, as: UTF8.self)
                let stderr = String(decoding: stderrData, as: UTF8.self)

                continuation.resume(returning: CommandResult(
                    status: terminated.terminationStatus,
                    stdout: stdout,
                    stderr: stderr
                ))
            }
        }
    }
}

struct URLSessionHTTPChecker: HTTPChecking {
    func check(url: URL, timeout: TimeInterval) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200...399).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

struct CoreWLANWiFiInfoProvider: WiFiInfoProviding {
    func currentInfo() -> WiFiInfo? {
        guard let iface = CWWiFiClient.shared().interface() else {
            return nil
        }

        return WiFiInfo(
            interface: iface.interfaceName,
            ssid: iface.ssid(),
            rssi: Int(iface.rssiValue()),
            powerOn: iface.powerOn()
        )
    }
}

enum Shell {
    static let networksetup = "/usr/sbin/networksetup"
    static let ipconfig = "/usr/sbin/ipconfig"
    static let route = "/sbin/route"
    static let ping = "/sbin/ping"
    static let dscacheutil = "/usr/bin/dscacheutil"

    static func airportCommand() -> String? {
        let candidates = [
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
