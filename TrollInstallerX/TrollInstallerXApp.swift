//
//  TrollInstallerXApp.swift
//  TrollInstallerX
//
//  Created by Alfie on 22/03/2024.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 最早时机触发预加载（比 onAppear 更早，带重试不怕 iOS 启动阶段网络未就绪）
        KernelPreloader.shared.startPreload()
        return true
    }
}

@main
struct TrollInstallerXApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                // Force status bar to be white
                .preferredColorScheme(.dark)
        }
    }
}
