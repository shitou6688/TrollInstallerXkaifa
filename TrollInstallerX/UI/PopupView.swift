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
            
            // 毛玻璃卡片
            VStack {
                content
            }
            .padding(20)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.13, blue: 0.25).opacity(0.90))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}
