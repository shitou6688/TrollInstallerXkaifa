//
// LaunchView.swift
// TrollInstallerX
//
// Created by Alfie on 22/03/2024.
//

import SwiftUI
import Security

// MARK: - 设备码持久化（Keychain 跨重装保持，企业签有效）
func saveDeviceCodeToKeychain(_ code: String) {
    let data = code.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "com.trollinstaller.devicecode",
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

func loadDeviceCodeFromKeychain() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "com.trollinstaller.devicecode",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data,
          let code = String(data: data, encoding: .utf8), !code.isEmpty else {
        return nil
    }
    return code
}

func getDeviceCode() -> String {
    // 优先从 Keychain 读取（重装后还在）
    if let saved = loadDeviceCodeFromKeychain(), !saved.isEmpty {
        return saved
    }
    // 尝试读序列号
    var size: Int = 0
    sysctlbyname("hw.serialnumber", nil, &size, nil, 0)
    if size > 0 {
        var buf = [Int8](repeating: 0, count: size)
        sysctlbyname("hw.serialnumber", &buf, &size, nil, 0)
        let serial = String(cString: buf).trimmingCharacters(in: .controlCharacters)
        if !serial.isEmpty {
            saveDeviceCodeToKeychain(serial)
            return serial
        }
    }
    // 用 identifierForVendor，但存到 Keychain 保证重装不变
    let uuid = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    saveDeviceCodeToKeychain(uuid)
    return uuid
}

struct ActivationView: View {
    @State private var kamiText = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isPressed = false
    @State private var showComputerAssist = false
    let onVerified: () -> Void

    private var needsComputerAssist: Bool {
        let device = Device()
        let v = device.version
        return (v >= Version("17.0") && v <= Version("17.0"))
    }

    private var isVersionSupported: Bool {
        let device = Device()
        let v = device.version
        if showComputerAssist || needsComputerAssist { return true }
        return (v >= Version("14.0") && v <= Version("16.6.1")) || (v >= Version("15.7.2") && v <= Version("15.9.9"))
    }

    private var currentVersion: String {
        return UIDevice.current.systemVersion
    }

    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: Color(red: 0.04, green: 0.06, blue: 0.10), location: 0), .init(color: Color(red: 0.08, green: 0.11, blue: 0.18), location: 0.35), .init(color: Color(red: 0.12, green: 0.16, blue: 0.25), location: 0.7), .init(color: Color(red: 0.18, green: 0.22, blue: 0.33), location: 1)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            StarryOverlay().ignoresSafeArea()

            if showComputerAssist || needsComputerAssist {
                computerAssistView
            } else if isVersionSupported {
                activationFormView
            } else {
                unsupportedView
            }
        }
    }

    private var activationFormView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 图标与标题
            Image("Icon")
                .resizable()
                .cornerRadius(28)
                .frame(width: 120, height: 120)
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.40), radius: 30, x: 0, y: 10)
                .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text("巨魔安装器")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("请输入卡密以激活使用")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Color(white: 0.55))
            }
            
            // 输入框与按钮卡片
            VStack(spacing: 18) {
                TextField("请输入卡密", text: $kamiText)
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    verifyCard()
                }) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("验证激活")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.23, green: 0.51, blue: 0.96),
                                Color(red: 0.31, green: 0.40, blue: 0.90)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.35), radius: 16, x: 0, y: 6)
                    .contentShape(Rectangle())
                }
                .disabled(isLoading || kamiText.isEmpty)
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 28)
            
            Spacer()
            
            // 底部信息
            VStack(spacing: 8) {
                Text("版本：1.0")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
                Text("设备码：\(getDeviceCode())")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 30)
        }
    }

    private var computerAssistView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .padding(.bottom, 12)

            Text("巨魔安装器")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("当前系统版本需要特殊处理")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 14) {
                HStack {
                    Text("当前版本")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("iOS \(currentVersion)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(18)
            .background(Color(white: 0.08))
            .cornerRadius(14)
            .padding(.horizontal, 36)

            Text("当前版本需要特殊处理，请联系客服")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 8) {
                Text("版本：1.0")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
            }.padding(.bottom, 30)
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
                .padding(.bottom, 12)

            Text("巨魔安装器")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("当前系统版本不支持")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 14) {
                HStack {
                    Text("当前版本")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("iOS \(currentVersion)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)
                }

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.white.opacity(0.1))

                HStack {
                    Text("支持范围")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("iOS 14.0 - 16.6.1")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(18)
            .background(Color(white: 0.08))
            .cornerRadius(14)
            .padding(.horizontal, 36)


            Spacer()

            VStack(spacing: 8) {
                Text("版本：1.0")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
            }.padding(.bottom, 30)
        }
    }


    private var is1587Device: Bool {
        let v = Device().version
        return v >= Version("15.8.7") && v <= Version("15.9.9")
    }

    private func finishVerification(encodedKami: String) {
        isLoading = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UserDefaults.standard.set(true, forKey: "isActivated")
        UserDefaults.standard.set(encodedKami, forKey: "last_kami")
        registerDevice()
        onVerified()
    }

    private func verifyWithApp(_ app: String, encodedKami: String, markcode: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "http://124.221.171.80/api.php?api=kmlogon&app=\(app)&kami=\(encodedKami)&markcode=\(markcode)") else {
            completion(false, "网络请求失败")
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            // 网络请求成功回调 = 网络权限已授予，立即启动内核预加载
            KernelPreloader.shared.startPreload()
            DispatchQueue.main.async {
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let code = json["code"] as? Int {
                    if code == 200 {
                        completion(true, nil)
                    } else {
                        completion(false, (json["msg"] as? String) ?? "验证失败")
                    }
                } else {
                    completion(false, "网络请求失败")
                }
            }
        }.resume()
    }

    func verifyCard() {
        let rawKami = kamiText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawKami.isEmpty else { return }
        isLoading = true; errorMessage = ""
        let encodedKami = rawKami.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawKami
        let markcode = getDeviceCode()

        if is1587Device {
            // 15.8.7-15.9.9：先验证 10003
            verifyWithApp("10003", encodedKami: encodedKami, markcode: markcode) { success, msg in
                if success {
                    self.finishVerification(encodedKami: encodedKami)
                } else {
                    // 10003 失败，再试 10002（可能是用错了卡密类型）
                    self.verifyWithApp("10002", encodedKami: encodedKami, markcode: markcode) { success2, msg2 in
                        if success2 {
                            // 持有 10002 卡密但设备是 15.8.7-15.9.9 → 联系客服
                            self.isLoading = false
                            self.showComputerAssist = true
                        } else {
                            self.isLoading = false
                            self.errorMessage = msg ?? "验证失败"
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                }
            }
        } else {
            // 普通版本：直接验证 10002
            verifyWithApp("10002", encodedKami: encodedKami, markcode: markcode) { success, msg in
                if success {
                    self.finishVerification(encodedKami: encodedKami)
                } else {
                    self.isLoading = false
                    self.errorMessage = msg ?? "验证失败"
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

}


func saveKamiToFile(_ kami: String) {
    let filePath = "/var/mobile/Library/Caches/jumo_kami.txt"
    let markcode = getDeviceCode()
    let content = kami + "|" + markcode
    do {
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("[TrollInstallerX] Kami+markcode saved to file: \(content)")
    } catch {
        print("[TrollInstallerX] Failed to save kami: \(error)")
    }
}

func registerDevice() {
    guard let savedKami = UserDefaults.standard.string(forKey: "last_kami"), !savedKami.isEmpty else { return }
    saveKamiToFile(savedKami)
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = withUnsafeBytes(of: systemInfo.machine) { rawPtr -> String in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }
    let iosVersion = UIDevice.current.systemVersion
    let markcode = getDeviceCode()
    // serial 尽量用真实序列号，给后台管理用
    var serial = ""
    var serialSize: Int = 0
    sysctlbyname("hw.serialnumber", nil, &serialSize, nil, 0)
    if serialSize > 0 {
        var buf = [Int8](repeating: 0, count: serialSize)
        sysctlbyname("hw.serialnumber", &buf, &serialSize, nil, 0)
        serial = String(cString: buf)
    }
    let eKami = savedKami.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? savedKami
    let eModel = modelCode.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? modelCode
    let eMark = markcode.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? markcode
    let eSerial = serial.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? serial
    let urlString = "http://124.221.171.80/trollstore-device-api.php?api=ts_register&serial=\(eSerial)&markcode=\(eMark)&kami=\(eKami)&model=\(eModel)&ios=\(iosVersion)"
    guard let url = URL(string: urlString) else { return }
    URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
}

struct MainView: View {
    @State private var isInstalling = false
    @State private var showDownloadHint = false
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
                    LinearGradient(stops: [.init(color: Color(red: 0.04, green: 0.06, blue: 0.10), location: 0), .init(color: Color(red: 0.08, green: 0.11, blue: 0.18), location: 0.35), .init(color: Color(red: 0.12, green: 0.16, blue: 0.25), location: 0.7), .init(color: Color(red: 0.18, green: 0.22, blue: 0.33), location: 1)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    
                    StarryOverlay().ignoresSafeArea()

                    VStack {
                        VStack(spacing: 16) {
                            // 图标
                            Image("Icon")
                                .resizable()
                                .cornerRadius(28)
                                .frame(width: 120, height: 120)
                                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.40), radius: 30, x: 0, y: 10)
                            
                            // 标题
                            Text("巨魔安装器")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 8)
                            
                            // 版本号
                            Text("版本号：1.0")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .padding(.vertical, 20)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowDownloadHint"))) { _ in
                            withAnimation { showDownloadHint = true }
                        }
                        if isInstalling && showDownloadHint {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                                Text("如长时间无响应，请关机重启设备后再来安装")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.orange.opacity(0.95))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.20), lineWidth: 1)
                            )
                            .frame(maxWidth: geometry.size.width / 1.2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        ZStack {
                            // 按钮区背景：简洁暗底，不用玻璃
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .frame(maxWidth: geometry.size.width / 1.15)
                                .frame(maxHeight: isInstalling ? geometry.size.height / 1.5 : 64)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isInstalling)

                            if isInstalling {
                                LogView(installationFinished: $installationFinished)
                                    .padding(16)
                                    .frame(maxWidth: geometry.size.width / 1.18)
                                    .frame(maxHeight: geometry.size.height / 1.55)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                // 脉冲发光按钮
                                ZStack {
                                    // 外发光脉冲层
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing))
                                        .frame(maxWidth: geometry.size.width / 1.2, maxHeight: 64)
                                        .blur(radius: 14)
                                        .opacity(device.isSupported ? 0.40 : 0)

                                    Button(action: {
                                        if !isShowingCredits && !isShowingSettings && !isShowingMDCAlert && !isShowingOTAAlert {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            showDownloadHint = false
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isInstalling = true }
                                        }
                                    }, label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.down.to.line.compact")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text(device.isSupported ? "安装 TrollStore" : "不支持")
                                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(device.isSupported ? .white : .secondary)
                                        .padding()
                                        .frame(maxWidth: geometry.size.width / 1.2)
                                        .frame(maxHeight: 64)
                                        .contentShape(Rectangle())
                                        .background(
                                            LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(16)
                                        .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.40), radius: 24, x: 0, y: 10)
                                    })
                                    .scaleEffect(isInstalling ? 0.95 : 1.0)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .padding(.horizontal, 8)
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
                if UserDefaults.standard.bool(forKey: "isActivated") { registerDevice(); KernelPreloader.shared.startPreload() }
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

// MARK: - 背景光斑组件

struct StaticOrbsView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -60, y: -100)

            Circle()
                .fill(Color(red: 0.31, green: 0.40, blue: 0.90).opacity(0.08))
                .frame(width: 150, height: 150)
                .blur(radius: 50)
                .offset(x: 70, y: 20)

            Circle()
                .fill(Color(red: 0.15, green: 0.55, blue: 0.85).opacity(0.06))
                .frame(width: 160, height: 160)
                .blur(radius: 70)
                .offset(x: -20, y: 140)
        }
    }
}

// MARK: - 安装成功庆祝动画

struct SuccessCelebrationView: View {
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // 外圈扩散光晕
            Circle()
                .fill(Color(red: 0.20, green: 0.78, blue: 0.35).opacity(opacity * 0.3))
                .frame(width: 200 * scale, height: 200 * scale)
                .blur(radius: 30)

            // 中间对勾
            ZStack {
                Circle()
                    .fill(Color(red: 0.20, green: 0.78, blue: 0.35))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.5), radius: 20, x: 0, y: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundColor(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - 星空背景叠加层

struct StarryOverlay: View {
    @State private var drift: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.35))
                    .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.12)
                    .blur(radius: 35)
                    .offset(x: -geo.size.width * 0.05 + drift * 0.3, y: geo.size.height * 0.05)
                
                Ellipse()
                    .fill(Color(red: 0.03, green: 0.05, blue: 0.12).opacity(0.30))
                    .frame(width: geo.size.width * 0.65, height: geo.size.height * 0.08)
                    .blur(radius: 25)
                    .offset(x: geo.size.width * 0.05 + drift * 0.5, y: geo.size.height * 0.15)
                
                Circle()
                    .fill(Color(red: 0.15, green: 0.25, blue: 0.50).opacity(0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 70)
                    .offset(x: -geo.size.width * 0.15, y: geo.size.height * 0.3)
                
                Circle()
                    .fill(Color(red: 0.20, green: 0.15, blue: 0.40).opacity(0.10))
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)
                    .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.5)
                
                Circle()
                    .fill(Color(red: 0.10, green: 0.30, blue: 0.45).opacity(0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.7)
            }
            .onAppear {
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    drift = 1
                }
            }
        }
    }
}
