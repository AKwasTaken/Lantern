//
//  AppDelegate.swift
//  Lantern
//
//  Created by Aneeth Kumaar on 25/07/26.
//

import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let warp = WarpManager.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon()

        if let button = statusItem.button {
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(warp)
        )

        warp.startPolling()

        warp.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)
    }

    // MARK: - Click handling (left = popover, right = menu)

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showMenu() {
        let menu = NSMenu()

        let dohItem = NSMenuItem(title: "1.1.1.1", action: #selector(selectDoH), keyEquivalent: "")
        dohItem.target = self
        dohItem.state = (warp.mode == .doh) ? .on : .off

        let warpItem = NSMenuItem(title: "1.1.1.1 with WARP", action: #selector(selectWarp), keyEquivalent: "")
        warpItem.target = self
        warpItem.state = (warp.mode == .warp) ? .on : .off

        menu.addItem(dohItem)
        menu.addItem(warpItem)
        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let aboutItem = NSMenuItem(title: "About Lantern", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    @objc func selectDoH() { warp.setMode(.doh) }
    @objc func selectWarp() { warp.setMode(.warp) }

    @objc func openPreferences() {
        popover.performClose(nil)
        PreferencesWindowController.shared.showWindow()
    }

    @objc func openAbout() {
        popover.performClose(nil)
        AboutWindowController.shared.showWindow()
    }

    // MARK: - Icon

    func updateStatusIcon() {
        let name = (warp.connectionState == .connected) ? "MenuBarConnected" : "MenuBarDisconnected"
        guard let image = NSImage(named: name) else { return }
        let targetHeight: CGFloat = 18
        let aspect = image.size.width / image.size.height
        image.size = NSSize(width: targetHeight * aspect, height: targetHeight)
        statusItem.button?.image = image
    }
}
