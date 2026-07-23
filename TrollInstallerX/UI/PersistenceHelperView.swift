//
//  PersistenceHelperView.swift
//  TrollInstallerX
//
//  Created by Alfie on 30/03/2024.
//

import SwiftUI

struct PersistenceHelperView: View {
    @Binding var isShowingHelperAlert: Bool
    let allowNoPersistenceHelper: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("持久性助手")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                if allowNoPersistenceHelper {
                    Text("如果您已经安装了一个持久性助手，请滚动到底部。")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 12)
            
            VStack(spacing: 16) {
                ForEach(persistenceHelperCandidates, id: \.self) { candidate in
                    Button(action: {
                        TIXDefaults().setValue(candidate.bundleIdentifier, forKey: "persistenceHelper")
                        withAnimation {
                            isShowingHelperAlert = false
                        }
                    }, label: {
                        HStack(spacing: 12) {
                            if let image = candidate.icon {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(12)
                            } else {
//                                Image(systemName: "gear")
//                                    .resizable()
//                                    .frame(width: 44, height: 44)
//                                    .cornerRadius(10)
                            }
                            Text(candidate.displayName)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    })
                }
                
                if allowNoPersistenceHelper {
                    Divider()
                        .padding(.vertical, 4)
                    
                    Button(action: {
                        TIXDefaults().setValue("", forKey: "persistenceHelper")
                        withAnimation {
                            isShowingHelperAlert = false
                        }
                    }, label: {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .cornerRadius(12)
                                .foregroundColor(.red)
                            Text("没有持久性助手")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    })
                    .padding(.bottom, 8)
                }
            }
        }
    }
}
