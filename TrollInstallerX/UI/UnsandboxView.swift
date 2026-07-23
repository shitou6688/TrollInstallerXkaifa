import SwiftUI

struct UnsandboxView: View {
    @Binding var isShowingMDCAlert: Bool
    var body: some View {
        VStack(spacing: 24) {
            Text("请点击安装巨魔")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
            
            Text("需要解除沙盒限制才能安装 TrollStore")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            
            Button(action: {
                UIImpactFeedbackGenerator().impactOccurred()
                grant_full_disk_access({ error in
                    if let error = error {
                        Logger.log("MacDirtyCow 解除沙盒失败", type: .error)
                    }
                    withAnimation {
                        isShowingMDCAlert = false
                    }
                })
            }, label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 180, height: 48)
                        .foregroundColor(.white.opacity(0.12))
                    Text("安装巨魔")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            })
            .padding(.vertical, 8)
        }
        .padding(30)
    }
}