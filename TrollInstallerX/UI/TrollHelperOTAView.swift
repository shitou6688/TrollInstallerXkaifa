//
//  TrollHelperOTAView.swift
//  TrollInstallerX
//
//  Created by Alfie on 26/03/2024.
//

import SwiftUI

struct TrollHelperOTAView: View {
    @Binding var arm64eVersion: Bool
    var body: some View {
            VStack(spacing: 20) {
                Text("TrollHelperOTA")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                Text("您的设备兼容TrollHelperOTA - 这是一种100%可靠的安装方法，无需通过侧载应用程序进行安装。您可以点击此提示之外的区域来关闭，或者按下下方的按钮通过OTA在线进行安装。")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.90))
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
                
                Button(action: {
                    UIImpactFeedbackGenerator().impactOccurred()
                    UIApplication.shared.open(URL(string: "https://api.jailbreaks.app/troll" + (arm64eVersion ? "64e" : ""))!)
                }, label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: 180, height: 48)
                            .foregroundColor(.white.opacity(0.12))
                        Text("在线OTA安装")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                })
                .padding(.vertical, 8)
            }
    }
}
