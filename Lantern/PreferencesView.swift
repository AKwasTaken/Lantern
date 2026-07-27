//
//  PreferencesView.swift
//  Lantern
//
//  Created by Aneeth Kumaar on 25/07/26.
//

import SwiftUI
import ServiceManagement

enum PreferenceTab: String, CaseIterable, Identifiable {
    case general = "General"
    case connection = "Connection"
    case dnsLogs = "DNS Logs"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .connection: return "network"
        case .dnsLogs: return "doc.text.magnifyingglass"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct PreferencesView: View {
    @State private var selectedTab: PreferenceTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                Text("Lantern")
                    .font(.system(size: 25, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                
                Divider()
                    .padding(.bottom, 8)

                ForEach(PreferenceTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 16)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .white : .primary.opacity(0.85))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity) // Expands the content to full width
                        .contentShape(Rectangle())  // Makes the entire full-width area hit-testable
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                Spacer()
            }
            .frame(width: 170)
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Detail View
            Group {
                switch selectedTab {
                case .general:
                    GeneralTab()
                case .connection:
                    ConnectionTab()
                case .dnsLogs:
                    DNSLogsTab()
                case .advanced:
                    AdvancedTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 600)
    }
}

// MARK: - General

struct GeneralTab: View {
    @EnvironmentObject var warp: WarpManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Connectivity information") {
                LabeledContent("Connection", value: warp.mode == .warp ? "Lantern" : "DNS only")
                LabeledContent("DNS protocol", value: warp.dnsProtocol)
                LabeledContent("Colocation center", value: warp.colo)
            }
            Section("Your device") {
                LabeledContent("Public IP", value: warp.publicIP)
                LabeledContent("Device ID", value: warp.deviceID)
                    .textSelection(.enabled)
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            print("Login item error: \(error)")
                        }
                    }
            } footer: {
                Text("Automatically start Lantern when you log in to your Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Connection

struct ConnectionTab: View {
    @EnvironmentObject var warp: WarpManager
    @State private var newSSID = ""
    @State private var disableWiFi = false
    @State private var disableWired = false
    @State private var familiesMode = "off"
    @State private var showResetKeysAlert = false

    var body: some View {
        Form {
            Section {
                ForEach(warp.trustedNetworks, id: \.self) { ssid in
                    HStack {
                        Text(ssid)
                        Spacer()
                        Button(role: .destructive) {
                            warp.removeTrustedNetwork(ssid)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Enter Wi-Fi network name", text: $newSSID)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        guard !newSSID.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        warp.addTrustedNetwork(newSSID.trimmingCharacters(in: .whitespaces))
                        newSSID = ""
                    }
                    .disabled(newSSID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Trusted networks")
            } footer: {
                Text("Lantern will pause when connected to one of these Wi-Fi networks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Disable for all Wi-Fi networks", isOn: Binding(
                    get: { disableWiFi },
                    set: { newValue in
                        disableWiFi = newValue
                        warp.setTrustedWiFiDisabled(newValue)
                    }
                ))

                Toggle("Disable for all wired networks", isOn: Binding(
                    get: { disableWired },
                    set: { newValue in
                        disableWired = newValue
                        warp.setTrustedEthernetDisabled(newValue)
                    }
                ))
            }

            Section("Mode") {
                Picker("Connection mode", selection: Binding(
                    get: { warp.mode },
                    set: { newValue in warp.setMode(newValue) }
                )) {
                    Text("DNS only").tag(WarpMode.doh)
                    Text("Lantern Tunnel").tag(WarpMode.warp)
                }

                Picker("Family Protection", selection: Binding(
                    get: { familiesMode },
                    set: { newValue in
                        familiesMode = newValue
                        warp.setFamiliesMode(newValue)
                    }
                )) {
                    Text("None").tag("off")
                    Text("Block Malware").tag("malware")
                    Text("Block Malware & Adult Content").tag("full")
                }
            }

            Section {
                HStack {
                    Button("Reset Encryption Keys") { showResetKeysAlert = true }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { warp.refreshTrustedNetworks() }
        .alert("Reset Encryption Keys?", isPresented: $showResetKeysAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                warp.rotateTunnelKeys()
            }
        }
    }
}

// MARK: - DNS Logs

struct DNSLogsTab: View {
    @State private var logging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Log DNS queries", isOn: $logging)
                .padding(.horizontal)
                .padding(.top, 12)

            Spacer()

            Divider()
            HStack {
                Text("Daemon logs:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(WarpManager.daemonLogPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: WarpManager.daemonLogPath)
                }
            }
            .padding()
        }
    }
}

// MARK: - Advanced

struct AdvancedTab: View {
    @EnvironmentObject var warp: WarpManager
    @State private var showSplitTunnel = false
    @State private var showLocalDomainFallback = false

    var body: some View {
        Form {
            Section("Statistics") {
                LabeledContent("Data received", value: warp.dataReceived)
                LabeledContent("Data sent", value: warp.dataSent)
                LabeledContent("Estimated latency", value: warp.latency)
            }

            Section {
                HStack {
                    Text("Exclude an IP address, range, or domain from the Lantern tunnel. Useful for apps that don't work well with tunneled connections.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Split Tunnel…") { showSplitTunnel = true }
                }
            }

            Section {
                HStack {
                    Text("Local Domain Fallback tells Lantern to ignore DNS requests for a list of domain suffixes, passing them to your existing network's DNS servers instead.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Local Domain Fallback…") { showLocalDomainFallback = true }
                }
            }

            Section {
                Picker("Proxy mode", selection: $warp.proxyMode) {
                    Text("Off").tag(ProxyMode.off)
                    Text("Automatic").tag(ProxyMode.automatic)
                    Text("Manual").tag(ProxyMode.manual)
                }
                .onChange(of: warp.proxyMode) { _, newValue in
                    warp.setProxyMode(newValue)
                }

                if warp.proxyMode == .manual {
                    TextField("Port", text: $warp.proxyPort)
                        .onSubmit { warp.setProxyPort(warp.proxyPort) }
                }
            } header: {
                Text("Proxy")
            } footer: {
                Text("Runs a local SOCKS/HTTPS proxy at localhost:\(warp.proxyPort), tunneled through Lantern.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            warp.refreshSplitTunnel()
            warp.refreshLocalDomainFallbacks()
        }
        .sheet(isPresented: $showSplitTunnel) {
            AddRemoveListSheet(
                title: "Split Tunnel",
                placeholder: "IP, range, or domain",
                items: $warp.splitTunnelExcludes,
                onAdd: { warp.addSplitTunnelExclude($0) },
                onRemove: { warp.removeSplitTunnelExclude($0) },
                onDone: { showSplitTunnel = false }
            )
        }
        .sheet(isPresented: $showLocalDomainFallback) {
            AddRemoveListSheet(
                title: "Local Domain Fallback",
                placeholder: "Domain suffix",
                items: $warp.localDomainFallbacks,
                onAdd: { warp.addLocalDomainFallback($0) },
                onRemove: { warp.removeLocalDomainFallback($0) },
                onDone: { showLocalDomainFallback = false }
            )
        }
    }
}

// MARK: - Reusable add/remove sheet

struct AddRemoveListSheet: View {
    let title: String
    let placeholder: String
    @Binding var items: [String]
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void
    let onDone: () -> Void

    @State private var newValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)

            List {
                if items.isEmpty {
                    Text("No items configured")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(items, id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button(role: .destructive) {
                                onRemove(item)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 160)

            HStack(spacing: 8) {
                TextField(placeholder, text: $newValue)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onAdd(trimmed)
                    newValue = ""
                }
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380)
    }
}
