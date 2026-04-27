import SwiftUI

struct UnsandboxView: View {
    @Binding var isShowingMDCAlert: Bool
    var body: some View {
        VStack(spacing: 20) {
            Text("请点击解除沙盒")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
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
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 175, height: 45)
                        .foregroundColor(.white.opacity(0.2))
                        .shadow(radius: 10)
                    Text("解除沙盒")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                }
            })
        }
        .padding(30)
    }
}