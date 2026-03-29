import Foundation

func defaultChecks() -> [any DiagnosticCheck] {
    [
        WiFiAssociationCheck(),
        LocalIPAddressCheck(),
        DHCPSanityCheck(),
        RouterReachabilityCheck(),
        DNSResolutionCheck(),
        InternetReachabilityCheck(),
        WiFiSignalQualityCheck()
    ]
}

struct WiFiAssociationCheck: DiagnosticCheck {
    let id = "wifi-association"
    let title = "Wi-Fi Connection"

    func run(context: DiagnosticsContext) async -> CheckResult {
        let hardware = await context.commandRunner.run(Shell.networksetup, ["-listallhardwareports"])
        guard hardware.status == 0 else {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Could not inspect Wi-Fi hardware",
                explanation: "The app could not read network hardware information.",
                recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
                technicalDetails: hardware.combinedOutput
            )
        }

        guard let wifiInterface = parseWiFiDevice(from: hardware.stdout) else {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "No Wi-Fi adapter found",
                explanation: "Your Mac does not appear to have an active Wi-Fi interface.",
                recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
                technicalDetails: hardware.stdout
            )
        }

        context.state.wifiInterface = wifiInterface

        let power = await context.commandRunner.run(Shell.networksetup, ["-getairportpower", wifiInterface])
        if power.status != 0 {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Could not read Wi-Fi power state",
                explanation: "The app could not confirm whether Wi-Fi is on.",
                recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
                technicalDetails: power.combinedOutput
            )
        }

        let powerText = power.stdout.lowercased()
        guard powerText.contains("on") else {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "Wi-Fi is turned off",
                explanation: "This Mac is not connected because Wi-Fi power is off.",
                recommendedAction: RemediationAction(label: "Toggle Wi-Fi", kind: .toggleWiFi),
                technicalDetails: power.stdout.trimmed
            )
        }

        let association = await context.commandRunner.run(Shell.networksetup, ["-getairportnetwork", wifiInterface])
        if association.status != 0 {
            return CheckResult(
                id: id,
                title: title,
                status: .warn,
                headline: "Wi-Fi is on, but network is unclear",
                explanation: "Wi-Fi power is on, but network name could not be read.",
                recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
                technicalDetails: association.combinedOutput
            )
        }

        if let ssid = parseSSID(from: association.stdout) {
            context.state.ssid = ssid
            return CheckResult(
                id: id,
                title: title,
                status: .pass,
                headline: "Connected to Wi-Fi",
                explanation: "This Mac is connected to \(ssid).",
                recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                technicalDetails: "Interface: \(wifiInterface)\nSSID: \(ssid)"
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .fail,
            headline: "Not connected to a Wi-Fi network",
            explanation: "Wi-Fi is on, but no network is currently connected.",
            recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
            technicalDetails: association.stdout.trimmed
        )
    }
}

struct LocalIPAddressCheck: DiagnosticCheck {
    let id = "local-ip"
    let title = "Local IP Address"

    func run(context: DiagnosticsContext) async -> CheckResult {
        guard let iface = context.state.wifiInterface else {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Wi-Fi interface unknown",
                explanation: "The app could not determine which network interface to inspect.",
                recommendedAction: RemediationAction(label: "Run checks again", kind: .none),
                technicalDetails: "Wi-Fi interface is nil"
            )
        }

        let ipResult = await context.commandRunner.run(Shell.ipconfig, ["getifaddr", iface])
        let ip = ipResult.stdout.trimmed

        guard ipResult.status == 0, !ip.isEmpty else {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "No local IP address",
                explanation: "This Mac did not receive a usable local address.",
                recommendedAction: RemediationAction(label: "Show DHCP renew steps", kind: .showRenewDHCPGuide),
                technicalDetails: ipResult.combinedOutput
            )
        }

        context.state.localIP = ip

        if ip.hasPrefix("169.254.") {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "Self-assigned IP address",
                explanation: "The Mac has a fallback address, which usually means DHCP failed.",
                recommendedAction: RemediationAction(label: "Show DHCP renew steps", kind: .showRenewDHCPGuide),
                technicalDetails: "IP: \(ip)"
            )
        }

        if ip.hasPrefix("127.") {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "Loopback address only",
                explanation: "The network adapter does not have a usable LAN address.",
                recommendedAction: RemediationAction(label: "Show DHCP renew steps", kind: .showRenewDHCPGuide),
                technicalDetails: "IP: \(ip)"
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .pass,
            headline: "Valid local IP address",
            explanation: "The Mac has a valid local address: \(ip).",
            recommendedAction: RemediationAction(label: "No action needed", kind: .none),
            technicalDetails: "IP: \(ip)"
        )
    }
}

struct DHCPSanityCheck: DiagnosticCheck {
    let id = "dhcp"
    let title = "DHCP and Gateway"

    func run(context: DiagnosticsContext) async -> CheckResult {
        let routeResult = await context.commandRunner.run(Shell.route, ["-n", "get", "default"])
        guard routeResult.status == 0 else {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "No default gateway",
                explanation: "The Mac does not have a default route, so internet traffic cannot leave the network.",
                recommendedAction: RemediationAction(label: "Show DHCP renew steps", kind: .showRenewDHCPGuide),
                technicalDetails: routeResult.combinedOutput
            )
        }

        guard let gateway = parseGateway(from: routeResult.stdout) else {
            return CheckResult(
                id: id,
                title: title,
                status: .fail,
                headline: "Gateway missing",
                explanation: "No router address was found in network routing.",
                recommendedAction: RemediationAction(label: "Show DHCP renew steps", kind: .showRenewDHCPGuide),
                technicalDetails: routeResult.stdout
            )
        }

        context.state.gateway = gateway

        let detail = "Gateway: \(gateway)\n\(routeResult.stdout.trimmed)"
        if context.state.localIP == nil {
            return CheckResult(
                id: id,
                title: title,
                status: .warn,
                headline: "Gateway found, but local IP is unclear",
                explanation: "The route looks good, but local IP check did not pass earlier.",
                recommendedAction: RemediationAction(label: "Show DHCP renew steps", kind: .showRenewDHCPGuide),
                technicalDetails: detail
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .pass,
            headline: "DHCP looks healthy",
            explanation: "A default gateway is present, so DHCP/routing looks normal.",
            recommendedAction: RemediationAction(label: "No action needed", kind: .none),
            technicalDetails: detail
        )
    }
}

struct RouterReachabilityCheck: DiagnosticCheck {
    let id = "router"
    let title = "Router Reachability"

    func run(context: DiagnosticsContext) async -> CheckResult {
        guard let gateway = context.state.gateway else {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Router address unavailable",
                explanation: "The router check could not run because gateway address is missing.",
                recommendedAction: RemediationAction(label: "Run checks again", kind: .none),
                technicalDetails: "Gateway was nil"
            )
        }

        let ping = await context.commandRunner.run(Shell.ping, ["-c", "1", "-t", "2", gateway])
        if ping.status == 0 {
            return CheckResult(
                id: id,
                title: title,
                status: .pass,
                headline: "Router is reachable",
                explanation: "The Mac can contact the local router at \(gateway).",
                recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                technicalDetails: ping.stdout.trimmed
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .fail,
            headline: "Router is not responding",
            explanation: "The Mac cannot ping the local router, which suggests local network trouble.",
            recommendedAction: RemediationAction(label: "Copy troubleshooting steps", kind: .copyTroubleshootingText),
            technicalDetails: ping.combinedOutput
        )
    }
}

struct DNSResolutionCheck: DiagnosticCheck {
    let id = "dns"
    let title = "DNS Resolution"

    private let hosts = ["google.com", "cloudflare.com"]

    func run(context: DiagnosticsContext) async -> CheckResult {
        var successes = 0
        var details: [String] = []

        for host in hosts {
            let result = await context.commandRunner.run(Shell.dscacheutil, ["-q", "host", "-a", "name", host])
            let hasAddress = result.status == 0 && result.stdout.contains("ip_address")
            if hasAddress {
                successes += 1
                details.append("\(host): resolved")
            } else {
                details.append("\(host): failed -> \(result.combinedOutput)")
            }
        }

        if successes == hosts.count {
            return CheckResult(
                id: id,
                title: title,
                status: .pass,
                headline: "DNS is working",
                explanation: "Domain names are resolving normally.",
                recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                technicalDetails: details.joined(separator: "\n")
            )
        }

        if successes > 0 {
            return CheckResult(
                id: id,
                title: title,
                status: .warn,
                headline: "DNS is unstable",
                explanation: "Some DNS lookups work, but not all.",
                recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
                technicalDetails: details.joined(separator: "\n")
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .fail,
            headline: "DNS is failing",
            explanation: "The Mac could not resolve common website names.",
            recommendedAction: RemediationAction(label: "Open Network Settings", kind: .openNetworkSettings),
            technicalDetails: details.joined(separator: "\n")
        )
    }
}

struct InternetReachabilityCheck: DiagnosticCheck {
    let id = "internet"
    let title = "Internet Reachability"

    func run(context: DiagnosticsContext) async -> CheckResult {
        let endpoints = [
            URL(string: "https://www.google.com/generate_204")!,
            URL(string: "https://captive.apple.com/hotspot-detect.html")!
        ]

        var details: [String] = []
        for url in endpoints {
            let ok = await context.httpChecker.check(url: url, timeout: 3)
            details.append("\(url.absoluteString): \(ok ? "ok" : "failed")")
            if ok {
                return CheckResult(
                    id: id,
                    title: title,
                    status: .pass,
                    headline: "Internet is reachable",
                    explanation: "The Mac successfully reached a public website.",
                    recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                    technicalDetails: details.joined(separator: "\n")
                )
            }
        }

        return CheckResult(
            id: id,
            title: title,
            status: .fail,
            headline: "No internet access",
            explanation: "Local network may be up, but public websites are not reachable.",
            recommendedAction: RemediationAction(label: "Copy troubleshooting steps", kind: .copyTroubleshootingText),
            technicalDetails: details.joined(separator: "\n")
        )
    }
}

struct WiFiSignalQualityCheck: DiagnosticCheck {
    let id = "signal"
    let title = "Wi-Fi Signal Quality"

    func run(context: DiagnosticsContext) async -> CheckResult {
        let airport = await context.commandRunner.run(Shell.airport, ["-I"])
        guard airport.status == 0 else {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Signal quality unavailable",
                explanation: "The app could not read Wi-Fi signal details.",
                recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                technicalDetails: airport.combinedOutput
            )
        }

        guard let rssi = parseRSSI(from: airport.stdout) else {
            return CheckResult(
                id: id,
                title: title,
                status: .unknown,
                headline: "Signal quality unavailable",
                explanation: "RSSI value was not found in Wi-Fi details.",
                recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                technicalDetails: airport.stdout
            )
        }

        if rssi >= -67 {
            return CheckResult(
                id: id,
                title: title,
                status: .pass,
                headline: "Wi-Fi signal is strong",
                explanation: "Signal strength looks healthy (RSSI \(rssi) dBm).",
                recommendedAction: RemediationAction(label: "No action needed", kind: .none),
                technicalDetails: "RSSI: \(rssi) dBm"
            )
        }

        if rssi >= -75 {
            return CheckResult(
                id: id,
                title: title,
                status: .warn,
                headline: "Wi-Fi signal is fair",
                explanation: "Signal is usable but may cause occasional slowness (RSSI \(rssi) dBm).",
                recommendedAction: RemediationAction(label: "Copy troubleshooting steps", kind: .copyTroubleshootingText),
                technicalDetails: "RSSI: \(rssi) dBm"
            )
        }

        return CheckResult(
            id: id,
            title: title,
            status: .warn,
            headline: "Wi-Fi signal is weak",
            explanation: "Weak signal can cause dropped calls and slow loading (RSSI \(rssi) dBm).",
            recommendedAction: RemediationAction(label: "Copy troubleshooting steps", kind: .copyTroubleshootingText),
            technicalDetails: "RSSI: \(rssi) dBm"
        )
    }
}

func parseWiFiDevice(from hardwarePorts: String) -> String? {
    let lines = hardwarePorts.split(separator: "\n").map(String.init)
    for idx in lines.indices where lines[idx].contains("Hardware Port: Wi-Fi") {
        let searchRange = lines.index(after: idx)..<min(lines.endIndex, idx + 4)
        for j in searchRange where lines[j].contains("Device:") {
            guard let value = lines[j].split(separator: ":", maxSplits: 1).last else {
                return nil
            }
            return String(value).trimmed
        }
    }
    return nil
}

func parseSSID(from output: String) -> String? {
    if output.contains("You are not associated") {
        return nil
    }

    guard let suffix = output.split(separator: ":", maxSplits: 1).last else {
        return nil
    }

    let value = String(suffix).trimmed
    return value.isEmpty ? nil : value
}

func parseGateway(from routeOutput: String) -> String? {
    for line in routeOutput.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("gateway:") {
            guard let value = trimmed.split(separator: ":", maxSplits: 1).last else {
                return nil
            }
            return String(value).trimmed
        }
    }
    return nil
}

func parseRSSI(from airportOutput: String) -> Int? {
    for line in airportOutput.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("agrCtlRSSI:") {
            let value = String(trimmed.split(separator: ":", maxSplits: 1).last ?? "").trimmed
            return Int(value)
        }
    }
    return nil
}
