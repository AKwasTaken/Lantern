//
//  PopoverView.swift
//  Lantern
//
//  Created by Aneeth Kumaar on 25/07/26.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


struct PopoverView: View {
    @EnvironmentObject var warp: WarpManager

    var body: some View {
        VStack(spacing: 0) {
            Text("lantern")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 30)

            Spacer(minLength: 20)

            Button(action: { warp.toggle() }) {
                Image(warp.connectionState == .connected ? "LogoConnected" : "LogoDisconnected")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
            }
            .buttonStyle(.plain)
            .disabled(!warp.cliAvailable || warp.connectionState == .connecting || warp.connectionState == .disconnecting)
            .opacity(warp.cliAvailable ? 1.0 : 0.4)

            Spacer(minLength: 22)

            combinedStatusLine
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 22)
                .frame(minHeight: 34)

            Spacer(minLength: 20)
        }
        .frame(width: 280, height: 360)
        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
    }

    @ViewBuilder
    private var combinedStatusLine: some View {
        switch warp.connectionState {
        case .connected:
            Text("Connected")
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "f4ce2f"))
                .multilineTextAlignment(.center)

        case .connecting:
            VStack(alignment: .center, spacing: 6) {
                Text("Connecting")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(warp.statusDetail)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

        case .disconnecting:
            Text("Disconnecting")
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

        case .disconnected:
            VStack(alignment: .center, spacing: 6) {
                Text("Disconnected")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Click the Lantern to turn on WARP")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

        case .failed, .error:
            let detail = warp.statusDetail.isEmpty ? "Try again." : warp.statusDetail
            VStack(alignment: .center, spacing: 6) {
                Text("Connection Failed")
                    .fontWeight(.bold)
                    .foregroundColor(Color.red.opacity(0.85))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    PopoverView().environmentObject(WarpManager.shared)
}
