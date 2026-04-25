import SwiftUI

struct ActivationView: View {
    @State private var kamiText = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    let onVerified: () -> Void
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.18), Color(red: 0.08, green: 0.13, blue: 0.24)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("巨魔安装器").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text("请输入卡密以激活使用").font(.subheadline).foregroundColor(Color(white: 0.6))
                VStack(spacing: 16) {
                    TextField("请输入卡密", text: $kamiText)
                        .padding(12).background(Color(white: 0.15)).cornerRadius(10).foregroundColor(.white).autocapitalization(.none).disableAutocorrection(true)
                    if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red) }
                    Button(action: verifyCard) {
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        else { Text("验证激活").fontWeight(.semibold).foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [Color(red: 0.4, green: 0.49, blue: 0.92), Color(red: 0.46, green: 0.29, blue: 0.64)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12).disabled(isLoading || kamiText.isEmpty)
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
        guard let url = URL(string: "http://124.221.171.80/api.php?api=kmlogon&app=10003&kami=\(encodedKami)&markcode=\(markcode)") else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let code = json["code"] as? Int {
                    if code == 200 { UserDefaults.standard.set(true, forKey: "isActivated"); onVerified() }
                    else { errorMessage = (json["msg"] as? String) ?? "验证失败" }
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
                LinearGradient(colors: [Color(red: 0.15, green: 0.55, blue: 0.95), Color(red: 0.1, green: 0.25, blue: 0.75)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("Icon")
                        .resizable()
                        .cornerRadius(22)
                        .frame(width: 120, height: 120)
                        .shadow(radius: 10)
                    Text("巨魔安装器")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 10)
                    Text("iOS 14.0 - 16.6.1")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 1)
                    Spacer()
                    if !isInstalling {
                        VStack(spacing: 16) {
                            Button(action: {
                                if !isShowingCredits && !isShowingSettings && !isShowingMDCAlert && !isShowingOTAAlert {
                                    UIImpactFeedbackGenerator().impactOccurred()
                                    withAnimation { isInstalling.toggle() }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                    Spacer()
                                    VStack(spacing: 2) {
                                        Text("开始安装")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("一键安装巨魔商店")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.55, blue: 0.1)], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            HStack(spacing: 12) {
                                Button(action: {
                                    if let url = URL(string: "https://ipa.jumo8.top") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "message.fill")
                                            .font(.system(size: 14))
                                        Text("联系客服")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 0.2, green: 0.7, blue: 0.3))
                                    .cornerRadius(12)
                                }
                                Button(action: {
                                    if let url = URL(string: "https://ipa.jumo8.top") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "questionmark.circle.fill")
                                            .font(.system(size: 14))
                                        Text("帮助教程")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 0.2, green: 0.5, blue: 0.9))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    } else {
                        LogView(installationFinished: $installationFinished)
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .foregroundColor(.white.opacity(0.15))
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 80)
                    }
                    Spacer().frame(height: 40)
                }
                .blur(radius: (isShowingMDCAlert || isShowingOTAAlert || isShowingSettings || isShowingCredits || helperView.showAlert) ? 10 : 0)
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
 
...(truncated)...