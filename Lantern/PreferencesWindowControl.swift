//
//  PreferencesWindowController.swift
//  Lantern
//

import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared: PreferencesWindowController = {
        let hosting = NSHostingController(
            rootView: PreferencesView().environmentObject(WarpManager.shared)
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Lantern Preferences"
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        
        return PreferencesWindowController(window: window)
    }()
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
