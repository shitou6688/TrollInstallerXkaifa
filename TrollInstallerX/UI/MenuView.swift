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
        Text("直接点击安装")
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.35))
    }
}
