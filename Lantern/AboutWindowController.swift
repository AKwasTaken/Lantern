//
//  AboutWindowController.swift
//  Lantern
//
//  Created by Aneeth Kumaar on 25/07/26.
//

import Cocoa
import SwiftUI

final class AboutWindowController: NSObject {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func showWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let w = NSWindow(contentViewController: hosting)
            w.title = "About Lantern"
            w.styleMask = [.titled, .closable]
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
