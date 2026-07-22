//
//  PopupView.swift
//  TrollInstallerX
//

import SwiftUI

struct PopupView<Content: View>: View {
    @Binding var isShowingAlert: Bool
    let shouldAllowDismiss: Bool
    var content: Content
    
    init(isShowingAlert: Binding<Bool>, shouldAllowDismiss: Bool = true, @ViewBuilder content: () -> Content) {
        self._isShowingAlert = isShowingAlert
        self.shouldAllowDismiss = shouldAllowDismiss
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // 半透明遮罩
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    if shouldAllowDismiss {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isShowingAlert = false
                        }
                    }
                }
            
            // 玻璃卡片（对齐卡密验证页风格）
            VStack {
                content
            }
            .padding(22)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 6)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}
