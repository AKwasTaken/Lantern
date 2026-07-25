//
//  AboutView.swift
//  Lantern
//
//  Created by Aneeth Kumaar on 25/07/26.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Safe image loading with fallback
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else if let fallbackIcon = NSImage(named: "AppIcon") {
                Image(nsImage: fallbackIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else {
                // Generic SF Symbol fallback if catalog is unassigned
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 4) {
                Text("Lantern")
                    .font(.system(size: 20, weight: .bold))
                Text("Version 1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text("A lightweight, native macOS menu bar client for Cloudflare WARP. Built to replace bloated background dashboards with a simple, distraction-free toggle.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)

            Divider()

            VStack(spacing: 2) {
                Text("Developed by Aneeth Kumaar")
                    .font(.system(size: 11, weight: .medium))
                Text("Powered by Cloudflare’s warp-cli")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
