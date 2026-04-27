//
// LaunchView.swift
// TrollInstallerX
//
// Created by Alfie on 22/03/2024.
//

import SwiftUI

struct ActivationView: View {
    @State private var kamiText = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isPressed = false
    let onVerified: () -> Void
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.106, green: 0.118, blue: 0.235), Color(red: 0.165, green: 0.188, blue: 0.282)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("巨魔安装器").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text("请输入卡密以激活使用").font(.subheadline).foregroundColor(Color(white: 0.6))
                VStack(spacing: 16) {
                    TextField("请输入卡密", text: $kamiText)
                        .padding(12).background(Color(white: 0.15)).cornerRadius(10).foregroundColor(.white).autocapitalization(.none).disableAutocorrection(true)
                    if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red) }
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        verifyCard()
                    }) {
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        else { Text("验证激活").fontWeight(.semibold).foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12).disabled(isLoading || kamiText.isEmpty)
                    .scaleEffect(isPressed ? 0.96 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
                }
                .padding(20).background(Color(white: 0.12)).cornerRadius(16).padding(.horizontal, 30)
                Spacer()
                VStack(spacing: 6) {
                    Text("📦 版本：1.0").font(.caption2).foregroundColor(.gray)
                    Text("💚 基于TrollInstallerX项目开发").font(.caption2).foregroundColor(.gray)
                }.padding(.bottom, 30)
            }
        }
    }
    func verifyCard() {
        guard !kamiText.isEmpty else { return }
        isLoading = true; errorMessage = ""
        let encodedKami = kamiText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? kamiText
        let markcode = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
guard let url = URL(string: "http://124.221.171.80/api.php?api=kmlogon&app=10002&kami=\(encodedKami)&markcode=\(markcode)") else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let code = json["code"] as? Int {
                    if code == 200 { UINotificationFeedbackGenerator().notificationOccurred(.success); UserDefaults.standard.set(true, forKey: "isActivated"); onVerified() }
                    else { UINotificationFeedbackGenerator().notificationOccurred(.error); errorMessage = (json["msg"] as? String) ?? "验证失败" }
                } else { errorMessage = "网络请求失败" }
            }
        }.resume()
    }
}

struct MainView: View {
    @State private var isInstalling = false
    @State private var showActivation = false
    @State private var device: Device = Device()
    @State private var isShowingMDCAlert = false
    @State private var isShowingOTAAlert = false
    @State private var isShowingHelperAlert = false
    @State private var isShowingSettings = false
    @State private var isShowingCredits = false
    @State private var installedSuccessfully = false
    @State private var installationFinished = false
    @ObservedObject var helperView = HelperAlert.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.106, green: 0.118, blue: 0.235), Color(red: 0.165, green: 0.188, blue: 0.282)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    VStack {
                        VStack {
                            Image("Icon")
                                .resizable()
                                .cornerRadius(22)
                                .frame(maxWidth: 120, maxHeight: 120)
                                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.4), radius: 20, x: 0, y: 5)
                                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.2), radius: 40, x: 0, y: 10)
                            Text("巨魔安装器")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 4)
                            Text("版本号：1.0")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .padding(.vertical)
                        if !isInstalling {
                            MenuView(isShowingSettings: $isShowingSettings, isShowingCredits: $isShowingCredits, isShowingMDCAlert: $isShowingMDCAlert, isShowingOTAAlert: $isShowingOTAAlert, device: device)
                                .frame(maxWidth: geometry.size.width / 1.2, maxHeight: geometry.size.height / 4)
                                .transition(.scale)
                                .padding()
                                .shadow(radius: 10)
                                .disabled(!device.isSupported)
                        }
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundColor(.white.opacity(0.08))
                                .frame(maxWidth: geometry.size.width / 1.2)
                                .frame(maxHeight: isInstalling ? geometry.size.height / 1.75 : 60)
                                .transition(.scale)
                                .shadow(radius: 10)
                            if isInstalling {
                                LogView(installationFinished: $installationFinished)
                                    .padding()
                                    .frame(maxWidth: geometry.size.width / 1.2)
                                    .frame(maxHeight: geometry.size.height / 1.75)
                            } else {
                                Button(action: {
                                    if !isShowingCredits && !isShowingSettings && !isShowingMDCAlert && !isShowingOTAAlert {
                                        UIImpactFeedbackGenerator().impactOccurred()
                                        withAnimation { isInstalling.toggle() }
                                    }
                                }, label: {
                                    Text(device.isSupported ? "安装 TrollStore" : "不支持")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundColor(device.isSupported ? .white : .secondary)
                                        .padding()
                                        .frame(maxWidth: geometry.size.width / 1.2)
                                        .frame(maxHeight: 60)
                                        .background(
                                            LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.35), radius: 16, x: 0, y: 8)
                                })
                                .frame(maxWidth: geometry.size.width / 1.2)
                                .frame(maxHeight: 60)
                            }
                        }
                        .padding()
                        .disabled(!device.isSupported)
                    }
                    .blur(radius: (isShowingMDCAlert || isShowingOTAAlert || isShowingSettings || isShowingCredits || helperView.showAlert) ? 10 : 0)
                }
                if isShowingOTAAlert {
                    PopupView(isShowingAlert: $isShowingOTAAlert, content: {
                        TrollHelperOTAView(arm64eVersion: .constant(false))
                    })
                }
                if isShowingMDCAlert {
                    PopupView(isShowingAlert: $isShowingMDCAlert, shouldAllowDismiss: false, content: {
                        UnsandboxView(isShowingMDCAlert: $isShowingMDCAlert)
                    })
                }
                if isShowingSettings {
                    PopupView(isShowingAlert: $isShowingSettings, content: {
                        SettingsView(device: device)
                    })
                }
                if isShowingCredits {
                    PopupView(isShowingAlert: $isShowingCredits, content: {
                        CreditsView()
                    })
                }
                if helperView.showAlert {
                    PopupView(isShowingAlert: $isShowingHelperAlert, shouldAllowDismiss: false, content: {
                        PersistenceHelperView(isShowingHelperAlert: $isShowingHelperAlert, allowNoPersistenceHelper: device.supportsDirectInstall)
                    })
                }
                if showActivation {
                    ZStack {
                        Color.black.opacity(0.8).ignoresSafeArea()
                        ActivationView {
                            withAnimation { showActivation = false }
                        }
                    }
                }
            }
            .onChange(of: helperView.showAlert) { new in
                if new { withAnimation { isShowingHelperAlert = true } }
            }
            .onChange(of: isShowingHelperAlert) { new in
                if !new { helperView.showAlert = false }
            }
            .onChange(of: isInstalling) { _ in
                Task {
                    if device.isSupported {
                        if device.supportsDirectInstall {
                            installedSuccessfully = await doDirectInstall(device)
                        } else {
                            installedSuccessfully = await doIndirectInstall(device)
                        }
                        installationFinished = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(installedSuccessfully ? .success : .error)
                }
            }
            .onChange(of: isShowingOTAAlert) { new in
                if !new { withAnimation { isShowingMDCAlert = !checkForMDCUnsandbox() && MacDirtyCow.supports(device) } }
            }
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "isActivated") { showActivation = true }
                if device.isSupported {
                    withAnimation {
                        isShowingOTAAlert = device.supportsOTA
                        if !isShowingOTAAlert { isShowingMDCAlert = !checkForMDCUnsandbox() && MacDirtyCow.supports(device) }
                    }
                }
                Task { await getUpdatedTrollStore() }
            }
            .onChange(of: isShowingOTAAlert) { new in
                if !new { withAnimation { isShowingMDCAlert = !checkForMDCUnsandbox() && MacDirtyCow.supports(device) } }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
