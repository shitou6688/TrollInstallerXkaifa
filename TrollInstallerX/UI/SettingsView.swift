//
//  SettingsView.swift
//  TrollInstallerX
//
//  Created by Alfie on 26/03/2024.
//

import SwiftUI

struct SettingsView: View {
    
    let device: Device
    
    @AppStorage("exploitFlavour", store: TIXDefaults()) var exploitFlavour: String = ""
    @AppStorage("verbose", store: TIXDefaults()) var verbose: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text("设置")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
            
            Button(action: {
                UIImpactFeedbackGenerator().impactOccurred()
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                try? FileManager.default.removeItem(atPath: docsDir.path + "/kernelcache")
            }, label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(maxWidth: 240)
                        .frame(maxHeight: 44)
                        .foregroundColor(.white.opacity(0.12))
                    Text("清除内核缓存")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            })
            .padding(.vertical, 8)
            
            if smith.supports(device) || physpuppet.supports(device) || darksword.supports(device) {
                Picker("Kernel exploit", selection: $exploitFlavour) {
                    Text("landa").foregroundColor(.white).tag("landa")
                    if smith.supports(device) {
                        Text("smith").foregroundColor(.white).tag("smith")
                    }
                    if physpuppet.supports(device) {
                        Text("physpuppet").foregroundColor(.white).tag("physpuppet")
                    }
                    if darksword.supports(device) {
                        Text("darksword").foregroundColor(.white).tag("darksword")
                    }
                }
                .pickerStyle(.segmented)
                .colorMultiply(.white)
                .padding(.horizontal, 8)
            }
            
            VStack {
                Toggle(isOn: $verbose, label: {
                    Text("详细日志记录")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                })
            }
            .padding(.horizontal, 8)
            
        }
        .onAppear {
            if exploitFlavour == "" {
                if darksword.supports(device) {
                    exploitFlavour = "darksword"
                } else {
                    exploitFlavour = physpuppet.supports(device) ? "physpuppet" : "landa"
                }
            }
        }
    }
}
