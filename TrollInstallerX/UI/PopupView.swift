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
            Color.black.opacity(0.50)
                .ignoresSafeArea()
                .onTapGesture {
                    if shouldAllowDismiss {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isShowingAlert = false
                        }
                    }
                }
            
            // 透明玻璃面板（透出背景星空）
            VStack {
                content
            }
            .padding(24)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.88)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}
