//
//  PreferencesWindowControl.swift
//  Lantern
//
//  Created by Aneeth Kumaar on 25/07/26.
//

import Cocoa
import SwiftUI

final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    func showWindow() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: PreferencesView().environmentObject(WarpManager.shared)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "Preferences"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.setContentSize(NSSize(width: 560, height: 490))
            w.center()
            w.delegate = self
            w.isReleasedWhenClosed = false
            
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .visible

            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
