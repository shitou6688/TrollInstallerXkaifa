import SwiftUI

struct ActivationView: View {
    @State private var kamiText = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    let onVerified: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.18),
                    Color(red: 0.08, green: 0.13, blue: 0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("巨魔安装器")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("请输入卡密以激活使用")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.6))

                VStack(spacing: 16) {
                    Text("输入卡密以激活使用")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.6))

                    TextField("请输入卡密", text: $kamiText)
                        .padding(12)
                        .background(Color(white: 0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: verifyCard) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("验证激活")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                Color(red: 0.46, green: 0.29, blue: 0.64)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .disabled(isLoading || kamiText.isEmpty)
                }
                .padding(20)
                .background(Color(white: 0.12))
                .cornerRadius(16)
                .padding(.horizontal, 30)

                Spacer()

                VStack(spacing: 6) {
                    Text("📦 版本：1.0")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("💚 基于TrollInstallerX项目开发")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("⚠️ 请确保给予WiFi和流量权限")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 30)
            }
        }
    }

    func verifyCard() {
        guard !kamiText.isEmpty else { return }
        isLoading = true
        errorMessage = ""

        let encodedKami = kamiText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? kamiText
        let urlString = "http://124.221.171.80/api.php?api=kmlogon&app=10003&kami=\(encodedKami)"
        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "URL格式错误"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["code"] as? Int {
                    if code == 200 {
                        UserDefaults.standard.set(true, forKey: "isActivated")
                        UserDefaults.standard.set(kamiText, forKey: "activatedKami")
                        onVerified()
                    } else {
                        let msg = json["msg"] as? String ?? "验证失败"
                        errorMessage = msg
                    }
                } else {
                    errorMessage = "网络请求失败，请检查网络"
                }
            }
        }.resume()
    }
}

struct ActivationChecker: ViewModifier {
    @State private var showActivation = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showActivation) {
                ActivationView {
                    showActivation = false
                }
            }
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "isActivated") {
                    showActivation = true
                }
            }
    }
}

extension View {
    func checkActivation() -> some View {
        self.modifier(ActivationChecker())
    }
}