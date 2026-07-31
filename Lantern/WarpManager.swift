import Foundation
import Combine

enum ConnectionState {
    case disconnected, connecting, connected, disconnecting, failed, error
}

enum WarpMode: String, CaseIterable {
    case doh = "doh"    // "1.1.1.1" — DNS-only, no tunnel
    case warp = "warp"  // "1.1.1.1 with WARP" — full tunnel
}

enum ProxyMode: String, CaseIterable {
    case off, automatic, manual
}

final class WarpManager: ObservableObject {

    static let shared = WarpManager()
    static let daemonLogPath = NSHomeDirectory() + "/Library/Logs/Cloudflare"

    @Published var connectionState: ConnectionState = .disconnected
    @Published var statusDetail: String = "Checking status…"
    @Published var mode: WarpMode = .warp
    @Published var accountType: String = "Free"
    @Published var publicIP: String = "—"
    @Published var colo: String = "—"
    @Published var dataSent: String = "—"
    @Published var dataReceived: String = "—"
    @Published var latency: String = "—"
    @Published var cliAvailable: Bool = false
    @Published var deviceID: String = "—"
    @Published var dnsProtocol: String = "WARP"
    @Published var trustedNetworks: [String] = []
    @Published var splitTunnelExcludes: [String] = []
    @Published var localDomainFallbacks: [String] = []
    @Published var proxyMode: ProxyMode = .off
    @Published var proxyPort: String = "40000"

    private var pollTimer: Timer?
    private let cliPath: String?

    private init() {
        cliPath = WarpManager.locateCLI()
        cliAvailable = cliPath != nil
        refreshStatus()
        refreshTrustedNetworks()
        refreshSplitTunnel()
    }

    // MARK: - Locating the CLI

    private static func locateCLI() -> String? {
        let candidates = [
            "/Applications/Cloudflare WARP.app/Contents/Resources/warp-cli",
            "/usr/local/bin/warp-cli",
            "/opt/homebrew/bin/warp-cli"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return which("warp-cli")
    }

    private static func which(_ tool: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [tool]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (output?.isEmpty == false) ? output : nil
        } catch {
            return nil
        }
    }

    // MARK: - Running commands

    @discardableResult
    private func run(_ args: [String]) -> (output: String, success: Bool) {
        guard let cliPath else { return ("warp-cli not found", false) }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = ["--accept-tos"] + args
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: outData, encoding: .utf8) ?? ""
            let err = String(data: errData, encoding: .utf8) ?? ""
            let combined = (out + err).trimmingCharacters(in: .whitespacesAndNewlines)
            return (combined, task.terminationStatus == 0)
        } catch {
            return ("Failed to run warp-cli: \(error.localizedDescription)", false)
        }
    }

    private func runAsync(_ args: [String], completion: @escaping (String, Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.run(args)
            DispatchQueue.main.async { completion(result.output, result.success) }
        }
    }

    // MARK: - Public actions
    
    func forceDisconnect() {
        connectionState = .disconnecting
//        statusDetail = "Force disconnecting..."
        
        runAsync(["disconnect"]) { [weak self] output, success in
            guard let self else { return }
            self.connectionState = .disconnected
//            self.statusDetail = "Disconnected"
            self.refreshStatus()
        }
    }

    func connect() {
        connectionState = .connecting
        statusDetail = "Initializing IP connection…"
        runAsync(["connect"]) { [weak self] output, success in
            guard let self else { return }
            if success {
                self.refreshStatus()
            } else {
                self.connectionState = .failed
                self.statusDetail = output.isEmpty ? "Connection failed." : output
            }
        }
    }

    func disconnect() {
        connectionState = .disconnecting
        statusDetail = "Disconnecting…"
        runAsync(["disconnect"]) { [weak self] output, success in
            guard let self else { return }
            if success {
                self.refreshStatus()
            } else {
                self.connectionState = .failed
                self.statusDetail = output.isEmpty ? "Disconnect failed." : output
            }
        }
    }

    func toggle() {
        switch connectionState {
        case .connected, .connecting:
            disconnect()
        default:
            connect()
        }
    }

    func setMode(_ newMode: WarpMode) {
        runAsync(["set-mode", newMode.rawValue]) { [weak self] _, success in
            if success { self?.mode = newMode }
            self?.refreshStatus()
        }
    }

    func startPolling(interval: TimeInterval = 2.0) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refreshStatus() {
        guard cliAvailable else {
            connectionState = .error
            statusDetail = "warp-cli not found. Install Cloudflare WARP once, then Lantern takes over."
            return
        }
        runAsync(["status"]) { [weak self] output, success in
            self?.parseStatus(output, success: success)
        }
    }

    // MARK: - Parsing
    
    private func parseStatus(_ output: String, success: Bool) {
        let lower = output.lowercased()

        if lower.contains("status update: connected") || (lower.contains("connected") && !lower.contains("disconnected") && !lower.contains("connecting")) {
            connectionState = .connected
            fetchDetails()
            statusDetail = "Connected"
        } else if lower.contains("connecting") {
            connectionState = .connecting
            statusDetail = "Initializing IP connection…"
        } else if lower.contains("disconnected") {
            connectionState = .disconnected
            statusDetail = "Disconnected"
        } else if !success {
            connectionState = .error
            statusDetail = output.isEmpty ? "Unable to reach warp-svc. Is it running?" : output
        } else {
            statusDetail = output
        }
    }
    
    private func fetchDetails() {
        runAsync(["tunnel", "stats"]) { [weak self] output, success in
            guard let self, success else { return }
            for rawLine in output.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("Sent:") {
                    for part in line.split(separator: ";") {
                        let kv = part.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                        guard kv.count == 2 else { continue }
                        if kv[0] == "Sent" { self.dataSent = kv[1] }
                        if kv[0] == "Received" { self.dataReceived = kv[1] }
                    }
                } else if line.hasPrefix("Estimated latency:") {
                    self.latency = line.replacingOccurrences(of: "Estimated latency:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Colo:") {
                    self.colo = line.replacingOccurrences(of: "Colo:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        runAsync(["registration", "show"]) { [weak self] output, success in
            guard let self, success else { return }
            for rawLine in output.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("Account type:") {
                    self.accountType = line.replacingOccurrences(of: "Account type:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Device ID:") {
                    self.deviceID = line.replacingOccurrences(of: "Device ID:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        fetchPublicIP()
    }

    private func fetchPublicIP() {
        guard let url = URL(string: "https://www.cloudflare.com/cdn-cgi/trace/") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let text = String(data: data, encoding: .utf8) else { return }
            guard let ipLine = text.split(separator: "\n").first(where: { $0.hasPrefix("ip=") }) else { return }
            let ip = ipLine.dropFirst(3)
            DispatchQueue.main.async { self.publicIP = String(ip) }
        }.resume()
    }

    private static func parseKeyValue(_ text: String) -> [(key: String, value: String)] {
        text.split(separator: "\n").compactMap { line in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (key, value)
        }
    }
    
    
    // MARK: - Trusted networks (VERIFIED)

    func refreshTrustedNetworks() {
            runAsync(["trusted", "ssid", "list"]) { [weak self] output, success in
                guard let self, success else { return }
                self.trustedNetworks = self.cleanListOutput(output)
            }
        }

    func addTrustedNetwork(_ ssid: String) {
        runAsync(["trusted", "ssid", "add", ssid]) { [weak self] _, _ in self?.refreshTrustedNetworks() }
    }

    func removeTrustedNetwork(_ ssid: String) {
        runAsync(["trusted", "ssid", "remove", ssid]) { [weak self] _, _ in self?.refreshTrustedNetworks() }
    }

    func setTrustedWiFiDisabled(_ disable: Bool) {
        runAsync(["trusted", "wifi", disable ? "enable" : "disable"]) { _, _ in }
    }

    func setTrustedEthernetDisabled(_ disable: Bool) {
        runAsync(["trusted", "ethernet", disable ? "enable" : "disable"]) { _, _ in }
    }


    // MARK: - Split tunnel (Custom Exclusions)

    private let defaultSystemSubnets: Set<String> = [
        "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10",
        "169.254.0.0/16", "fe80::/10", "fd00::/8"
    ]

    func refreshSplitTunnel() {
        var combined: [String] = []
        let group = DispatchGroup()

        group.enter()
        runAsync(["tunnel", "host", "list"]) { [weak self] output, success in
            if success, let self {
                combined.append(contentsOf: self.cleanListOutput(output))
            }
            group.leave()
        }

        group.enter()
        runAsync(["tunnel", "ip", "list"]) { [weak self] output, success in
            if success, let self {
                let userIPs = self.cleanListOutput(output).filter { !self.defaultSystemSubnets.contains($0) }
                combined.append(contentsOf: userIPs)
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            var seen = Set<String>()
            let uniqueOrdered = combined.filter { seen.insert($0).inserted }
            
            self?.splitTunnelExcludes = uniqueOrdered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }



    func addSplitTunnelExclude(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if isIPAddress(trimmed) {
            print("Split Tunnel host list only accepts domains (e.g. example.com). Use domain hostnames instead of IP addresses.")
            return
        }

        if !splitTunnelExcludes.contains(trimmed) {
            splitTunnelExcludes.append(trimmed)
        }

        runAsync(["tunnel", "host", "add", trimmed]) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refreshSplitTunnel()
            }
        }
    }

    func removeSplitTunnelExclude(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        splitTunnelExcludes.removeAll { $0 == trimmed }

        runAsync(["tunnel", "host", "remove", trimmed]) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refreshSplitTunnel()
            }
        }
    }


    private func isIPAddress(_ string: String) -> Bool {
        let ipCandidate = string.components(separatedBy: "/").first ?? string
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        return inet_pton(AF_INET, ipCandidate, &sin.sin_addr) == 1 ||
               inet_pton(AF_INET6, ipCandidate, &sin6.sin6_addr) == 1
    }



    // MARK: - Fallback Domains / Local Domain Fallback (CORRECTED: `dns fallback`)

    func refreshLocalDomainFallbacks() {
            runAsync(["dns", "fallback", "list"]) { [weak self] output, success in
                guard let self, success else { return }
                self.localDomainFallbacks = self.cleanListOutput(output)
            }
        }

    func addLocalDomainFallback(_ domain: String) {
            let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            if !localDomainFallbacks.contains(trimmed) {
                localDomainFallbacks.append(trimmed)
            }
            
            runAsync(["dns", "fallback", "add", trimmed]) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.refreshLocalDomainFallbacks()
                }
            }
        }

        func removeLocalDomainFallback(_ domain: String) {
            let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            
            localDomainFallbacks.removeAll { $0 == trimmed }
            
            runAsync(["dns", "fallback", "remove", trimmed]) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.refreshLocalDomainFallbacks()
                }
            }
        }


    // MARK: - Families Mode & Key Reset (NEWLY WIRED)

    func setFamiliesMode(_ mode: String) {
        runAsync(["dns", "families", mode]) { _, _ in }
    }

    func rotateTunnelKeys() {
        runAsync(["tunnel", "rotate-keys"]) { _, _ in }
    }
    
    
    // MARK: - Proxy

    func setProxyMode(_ m: ProxyMode) {
        runAsync(["set-proxy-mode", m.rawValue]) { [weak self] _, success in
            if success { self?.proxyMode = m }
        }
    }

    func setProxyPort(_ port: String) {
        runAsync(["set-proxy-port", port]) { [weak self] _, success in
            if success { self?.proxyPort = port }
        }
    }
    
    
    // MARK: - Helper to Clean CLI Output Strings

       private func cleanListOutput(_ output: String) -> [String] {
           return output
               .split(separator: "\n")
               .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
               .compactMap { line -> String? in
                   var text = line
                   
                   if text.hasPrefix("* ") || text.hasPrefix("- ") {
                       text = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                   }
                   
                   if let parenIndex = text.firstIndex(of: "(") {
                       text = String(text[..<parenIndex]).trimmingCharacters(in: .whitespaces)
                   }
                   
                   guard !text.isEmpty else { return nil }
                   
                   let lower = text.lowercased()
                   if lower.hasSuffix(":") || lower.contains("excluded hosts") || lower.contains("fallback domains") || lower.contains("trusted ssids") {
                       return nil
                   }
                   
                   return text
               }
       }


}
