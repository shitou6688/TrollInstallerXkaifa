//
//  MenuView.swift
//  TrollInstallerX
//

import SwiftUI

struct MenuView: View {
    @Binding var isShowingSettings: Bool
    @Binding var isShowingCredits: Bool
    @Binding var isShowingMDCAlert: Bool
    @Binding var isShowingOTAAlert: Bool
    let device: Device
    
    var body: some View {
        VStack(spacing: 0) {
            MenuRow(
                icon: "gearshape",
                title: "设置",
                action: {
                    guard !isShowingCredits, !isShowingMDCAlert, !isShowingOTAAlert else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { isShowingSettings = true }
                }
            )
            
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            MenuRow(
                icon: "info.circle",
                title: "关于",
                action: {
                    guard !isShowingSettings, !isShowingMDCAlert, !isShowingOTAAlert else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { isShowingCredits = true }
                }
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
