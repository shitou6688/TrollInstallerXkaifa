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
            LinearGradient(colors: [Color(red: 0.106, green: 0.118, blue: 0.235), Color(red: 0.165, green: 0.188, blue: 0.282)], startPoint: .top, endPoint: .bottom)
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
        VStack(spacing: 20) {
            Spacer()
            Text("巨魔安装器").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("请输入卡密以激活使用").font(.subheadline).foregroundColor(Color(white: 0.6))
            VStack(spacing: 16) {
                TextField("请输入卡密", text: $kamiText)
                    .padding(12).background(Color.white.opacity(0.10)).cornerRadius(10).foregroundColor(.white).autocapitalization(.none).disableAutocorrection(true)
                if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red) }
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    verifyCard()
                }) {
                    Group {
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                        else { Text("验证激活").fontWeight(.semibold).foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                }
                .disabled(isLoading || kamiText.isEmpty)
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 30)
            Spacer()
            VStack(spacing: 6) {
                Text("版本：1.0").font(.caption2).foregroundColor(.gray)
                Text("设备码：\(getDeviceCode())").font(.caption2).foregroundColor(.gray)
            }.padding(.bottom, 30)
        }
    }

    private var computerAssistView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 56))
                .foregroundColor(.blue)
                .padding(.bottom, 8)

            Text("巨魔安装器")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("当前系统版本需要特殊处理")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 12) {
                HStack {
                    Text("当前版本")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("iOS \(currentVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(Color(white: 0.1))
            .cornerRadius(12)
            .padding(.horizontal, 36)

            Text("当前版本需要特殊处理，请联系客服")
                .font(.subheadline)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 6) {
                Text("版本：1.0").font(.caption2).foregroundColor(.gray)
            }.padding(.bottom, 30)
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)
                .padding(.bottom, 8)

            Text("巨魔安装器")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("当前系统版本不支持")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 12) {
                HStack {
                    Text("当前版本")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("iOS \(currentVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.white.opacity(0.1))

                HStack {
                    Text("支持范围")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("iOS 14.0 - 16.6.1")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(Color(white: 0.1))
            .cornerRadius(12)
            .padding(.horizontal, 36)


            Spacer()

            VStack(spacing: 6) {
                Text("版本：1.0").font(.caption2).foregroundColor(.gray)
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
    @State private var showSuccessCelebration = false
    @ObservedObject var helperView = HelperAlert.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.106, green: 0.118, blue: 0.235), Color(red: 0.165, green: 0.188, blue: 0.282)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    
                    StarryOverlay().ignoresSafeArea()

                    VStack {
                        VStack {
                            Image("Icon")
                                .resizable()
                                .cornerRadius(24)
                                .frame(width: 100, height: 100)
                                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.30), radius: 24, x: 0, y: 8)
                            Text("巨魔安装器")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 4)
                            Text("版本号：1.0")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .padding(.vertical)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowDownloadHint"))) { _ in
                            withAnimation { showDownloadHint = true }
                        }
                        if isInstalling && showDownloadHint {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("如长时间无响应，请关机重启设备后再来安装")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.orange.opacity(0.9))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.12))
                            )
                            .frame(maxWidth: geometry.size.width / 1.2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        ZStack {
                            // 按钮区背景：简洁暗底，不用玻璃
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .frame(maxWidth: geometry.size.width / 1.18)
                                .frame(maxHeight: isInstalling ? geometry.size.height / 1.7 : 58)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isInstalling)

                            if isInstalling {
                                LogView(installationFinished: $installationFinished)
                                    .padding(10)
                                    .frame(maxWidth: geometry.size.width / 1.2)
                                    .frame(maxHeight: geometry.size.height / 1.75)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                // 脉冲发光按钮
                                ZStack {
                                    // 外发光脉冲层
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing))
                                        .frame(maxWidth: geometry.size.width / 1.2, maxHeight: 60)
                                        .blur(radius: 12)
                                        .opacity(device.isSupported ? 0.35 : 0)

                                    Button(action: {
                                        if !isShowingCredits && !isShowingSettings && !isShowingMDCAlert && !isShowingOTAAlert {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            showDownloadHint = false
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isInstalling = true }
                                        }
                                    }, label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.to.line.compact")
                                                .font(.system(size: 15, weight: .semibold))
                                            Text(device.isSupported ? "安装 TrollStore" : "不支持")
                                                .font(.system(size: 21, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(device.isSupported ? .white : .secondary)
                                        .padding()
                                        .frame(maxWidth: geometry.size.width / 1.2)
                                        .frame(maxHeight: 60)
                                        .contentShape(Rectangle())
                                        .background(
                                            LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.31, green: 0.40, blue: 0.90)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.30), radius: 20, x: 0, y: 8)
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

                // 安装成功庆祝动画
                if showSuccessCelebration {
                    SuccessCelebrationView()
                        .transition(.opacity)
                        .zIndex(100)
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
                        if installedSuccessfully {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                                showSuccessCelebration = true
                            }
                            // 3秒后自动收起庆祝效果回到初始状态
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            withAnimation(.easeOut(duration: 0.5)) {
                                showSuccessCelebration = false
                            }
                        }
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
    @State private var twinkle: Bool = false
    @State private var cloudDrift: CGFloat = 0
    
    private let stars: [StarPoint] = StarryOverlay.generateStars(count: 250)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ===== 星云带（上半部分，缓慢飘动） =====
                // 云带 1 — 左上横向
                Ellipse()
                    .fill(Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.45))
                    .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.15)
                    .blur(radius: 35)
                    .offset(x: -geo.size.width * 0.1 + cloudDrift * 0.3,
                            y: geo.size.height * 0.05)
                
                // 云带 2 — 中部偏左丝状
                Ellipse()
                    .fill(Color(red: 0.04, green: 0.06, blue: 0.13).opacity(0.40))
                    .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.10)
                    .blur(radius: 30)
                    .offset(x: geo.size.width * 0.05 + cloudDrift * 0.5,
                            y: geo.size.height * 0.18)
                
                // 云带 3 — 右上薄纱
                Ellipse()
                    .fill(Color(red: 0.03, green: 0.05, blue: 0.12).opacity(0.35))
                    .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.08)
                    .blur(radius: 25)
                    .offset(x: geo.size.width * 0.15 - cloudDrift * 0.4,
                            y: geo.size.height * 0.28)
                
                // ===== 星星 =====
                ForEach(stars) { star in
                    // 冰蓝色调的星点（冷白略带蓝）
                    let starColor = Color(red: 0.82 + star.blueShift * 0.18,
                                          green: 0.88 + star.blueShift * 0.12,
                                          blue: 1.0)
                    Circle()
                        .fill(starColor.opacity(twinkle ? star.opacity : star.opacity * 0.3))
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                        .animation(
                            Animation.easeInOut(duration: star.duration)
                                .repeatForever(autoreverses: true)
                                .delay(star.delay),
                            value: twinkle
                        )
                }
            }
            .onAppear {
                twinkle = true
                // 云朵缓慢飘动
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    cloudDrift = 1
                }
            }
        }
    }
    
    struct StarPoint: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
        let duration: Double
        let delay: Double
        let blueShift: Double  // 0=纯白, 1=偏冰蓝
    }
    
    static func generateStars(count: Int) -> [StarPoint] {
        var stars: [StarPoint] = []
        var seed: UInt64 = 42
        for _ in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1
            let x = CGFloat((seed >> 32) & 0xFFFF) / 65535.0
            seed = seed &* 6364136223846793005 &+ 1
            let y = CGFloat((seed >> 32) & 0xFFFF) / 65535.0
            seed = seed &* 6364136223846793005 &+ 1
            // 极小星点 0.8-3.0pt
            let size = CGFloat(0.8 + Double((seed >> 32) & 0xF) * 0.14)
            seed = seed &* 6364136223846793005 &+ 1
            let opacity = 0.10 + Double((seed >> 32) & 0x7F) / 128.0 * 0.50
            seed = seed &* 6364136223846793005 &+ 1
            let duration = 2.0 + Double((seed >> 32) & 0x1F) * 0.3
            seed = seed &* 6364136223846793005 &+ 1
            let delay = Double((seed >> 32) & 0xFFF) / 4096.0 * 5.0
            seed = seed &* 6364136223846793005 &+ 1
            let blueShift = Double((seed >> 32) & 0x3F) / 64.0
            stars.append(StarPoint(x: x, y: y, size: size, opacity: opacity, duration: duration, delay: delay, blueShift: blueShift))
        }
        return stars
    }
}
