//
// ===== 内核镜像下载 =====
func downloadKernelFromMirror(_ device: Device) -> Bool {
    Logger.log("正在从镜像源下载内核...")
    let modelID = device.modelIdentifier
    let versionStr = device.version.readableString
    let fixedModel = modelID.replacingOccurrences(of: ",", with: ".")
    let exactURL = "https://kernel0.jumo8.top/\(fixedModel)_\(versionStr).kernelcache"
    if let data = try? Data(contentsOf: URL(string: exactURL)!) {
        if data.count > 100000 {
            do {
                try data.write(to: URL(fileURLWithPath: kernelPath))
                Logger.log("镜像下载成功", type: .success)
                return true
            } catch { Logger.log("内核保存失败", type: .error) }
        }
    }
    let parts = versionStr.split(separator: ".")
    if parts.count >= 2 {
        let shortVersion = "\((parts[0])).\((parts[1]))"
        let fallbackURL = "https://kernel0.jumo8.top/\(fixedModel)_\(shortVersion).kernelcache"
        if let data = try? Data(contentsOf: URL(string: fallbackURL)!) {
            if data.count > 100000 {
                do {
                    try data.write(to: URL(fileURLWithPath: kernelPath))
                    Logger.log("镜像下载成功", type: .success)
                    return true
                } catch { Logger.log("内核保存失败", type: .error) }
            }
        }
    }

    // ===== iPad 备用镜像�?=====
    if modelID.hasPrefix("iPad") {
        Logger.log("主镜像未找到 iPad 内核，尝试备用镜像源...")

        let iPadExactURL = "https://kernel0.jumo8.top/ipad/\(fixedModel)_\(versionStr).kernelcache"
        if let data = try? Data(contentsOf: URL(string: iPadExactURL)!) {
            if data.count > 100000 {
                do {
                    try data.write(to: URL(fileURLWithPath: kernelPath))
                    Logger.log("备用镜像源下载成�?, type: .success)
                    return true
                } catch { Logger.log("内核保存失败", type: .error) }
            }
        }

        if parts.count >= 2 {
            let shortVersion = "\((parts[0])).\((parts[1]))"
            let iPadFallbackURL = "https://kernel0.jumo8.top/ipad/\(fixedModel)_\(shortVersion).kernelcache"
            if let data = try? Data(contentsOf: URL(string: iPadFallbackURL)!) {
                if data.count > 100000 {
                    do {
                        try data.write(to: URL(fileURLWithPath: kernelPath))
                        Logger.log("备用镜像源下载成�?, type: .success)
                        return true
                    } catch { Logger.log("内核保存失败", type: .error) }
                }
            }
        }
    }

    Logger.log("镜像下载未找到匹配内�?, type: .warning)
    return false
}
//  Installation.swift
//  TrollInstallerX
//
//  Created by Alfie on 22/03/2024.
//

import SwiftUI

let fileManager = FileManager.default
let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].path
let kernelPath = docsDir + "/kernelcache"


func checkForMDCUnsandbox() -> Bool {
    return fileManager.fileExists(atPath: docsDir + "/full_disk_access_sandbox_token.txt")
}

func getKernel(_ device: Device) -> Bool {
    Logger.log("正在下载内核(不要切屏)请稍�?..")
    
    // 创建一个信号量，用于控制超�?
    let semaphore = DispatchSemaphore(value: 0)
    var kernelDownloaded = false
    
    // 超时提示
    DispatchQueue.global().asyncAfter(deadline: .now() + 120) { // 2分钟
        if !kernelDownloaded {
            Logger.log("长时间无响应，请关机重启一下，或者换流量再来点�?, type: .warning)
        }
    }
    
    while true {  // 持续尝试直到成功
        if fileManager.fileExists(atPath: kernelPath) {
            Logger.log("内核缓存已存�?)
            kernelDownloaded = true
            return true
        }
        
        // 检查是否有捆绑的内核缓�?
        if fileManager.fileExists(atPath: Bundle.main.path(forResource: "kernelcache", ofType: "") ?? "") {
            do {
                try fileManager.copyItem(atPath: Bundle.main.path(forResource: "kernelcache", ofType: "")!, toPath: kernelPath)
                if fileManager.fileExists(atPath: kernelPath) { 
                    Logger.log("已使用捆绑的内核缓存文件")
                    kernelDownloaded = true
                    return true 
                }
            } catch {
                Logger.log("复制捆绑内核缓存失败: \(error.localizedDescription)", type: .error)
            }
        }
        
        // 使用MacDirtyCow尝试获取内核缓存
        if MacDirtyCow.supports(device) && checkForMDCUnsandbox() {
            let fd = open(docsDir + "/full_disk_access_sandbox_token.txt", O_RDONLY)
            if fd > 0 {
                let tokenData = get_NSString_from_file(fd)
                sandbox_extension_consume(tokenData)
                let path = get_kernelcache_path()
                do {
                    try fileManager.copyItem(atPath: path!, toPath: kernelPath)
                    Logger.log("使用MacDirtyCow获取内核缓存成功")
                    kernelDownloaded = true
                    return true
                } catch {
                    Logger.log("复制内核缓存失败: \(error.localizedDescription)", type: .error)
                }
            }
        }
        
        // 尝试下载内核
if downloadKernelFromMirror(device) {
    Logger.log("内核下载成功")
    kernelDownloaded = true
    return true
}
        if grab_kernelcache(kernelPath) {
            Logger.log("内核下载成功")
            kernelDownloaded = true
            return true
        }
    }
}


func cleanupPrivatePreboot() -> Bool {
    // Remove /private/preboot/tmp
    let fileManager = FileManager.default
    do {
        try fileManager.removeItem(atPath: "/private/preboot/tmp")
    } catch let e {
        print("Failed to remove /private/preboot/tmp! \(e.localizedDescription)")
        return false
    }
    return true
}

func selectExploit(_ device: Device) -> KernelExploit {
    let flavour = (TIXDefaults().string(forKey: "exploitFlavour") ?? (physpuppet.supports(device) ? "physpuppet" : "landa"))
    if flavour == "landa" { return landa }
    if flavour == "physpuppet" { return physpuppet }
    if flavour == "smith" { return smith }
    return landa
}

func getCandidates() -> [InstalledApp] {
    var apps = [InstalledApp]()
    for candidate in persistenceHelperCandidates {
        if candidate.isInstalled { apps.append(candidate) }
    }
    return apps
}

func tryInstallPersistenceHelper(_ candidates: [InstalledApp]) -> Bool {
    for candidate in candidates {
        Logger.log("正在尝试安装持久性助手到 \(candidate.displayName)")
        if install_persistence_helper(candidate.bundleIdentifier) {
            Logger.log("成功安装持久性助手到 \(candidate.displayName)�?, type: .success)
            return true
        }
        Logger.log("安装失败，尝试下一个应�?, type: .error)
    }
    Logger.log("所有应用都安装失败", type: .error)
    return false
}

// 添加内核查找函数的更健壮版本
func robustInitialiseKernelInfo(_ kernelPath: String, _ iOS14: Bool) -> Bool {
    for attempt in 1...3 {
        Logger.log("正在查找内核漏洞 (尝试 \(attempt)/3)")
        if initialise_kernel_info(kernelPath, iOS14) {
            Logger.log("查找内核漏洞成功")
            return true
        }
        
        Logger.log("查找内核漏洞失败，将尝试重试", type: .error)
        // 短暂等待后重�?
        sleep(1)
    }
    
    Logger.log("查找内核漏洞失败，已尝试3�?, type: .error)
    return false
}

@discardableResult
func doDirectInstall(_ device: Device) async -> Bool {
    
    let exploit = selectExploit(device)
    
    let iOS14 = device.version < Version("15.0")
    let supportsFullPhysRW = !(device.cpuFamily == .A8 && device.version > Version("15.1.1")) && ((device.isArm64e && device.version >= Version(major: 15, minor: 2)) || (!device.isArm64e && device.version >= Version("15.0")))
    
    Logger.log("正运行在 \(device.modelIdentifier) 设备上的 iOS 版本�?\(device.version.readableString)")
    
    if !iOS14 {
        if !(getKernel(device)) {
            Logger.log("获取内核漏洞失败", type: .error)
            return false
        }
    }
    
    Logger.log("正在查找内核漏洞")
    if !robustInitialiseKernelInfo(kernelPath, iOS14) {
        Logger.log("查找内核漏洞失败", type: .error)
        return false
    }
    
    Logger.log("正在利用内核 (\(exploit.name)) 漏洞")
    if !exploit.initialise() {
        Logger.log("利用内核漏洞失败", type: .error)
        return false
    }
    Logger.log("成功利用内核漏洞", type: .success)
    post_kernel_exploit(iOS14)
    
    var trollstoreTarData: Data?
    if FileManager.default.fileExists(atPath: docsDir + "/TrollStore.tar") {
        trollstoreTarData = try? Data(contentsOf: docsURL.appendingPathComponent("TrollStore.tar"))
    }
    
    if supportsFullPhysRW {
        if device.isArm64e {
            Logger.log("正在绕过 PPL (\(dmaFail.name))")
            if !dmaFail.initialise() {
                Logger.log("绕过 PPL 失败", type: .error)
                return false
            }
            Logger.log("成功绕过 PPL", type: .success)
        }
        
        if #available(iOS 16, *) {
            libjailbreak_kalloc_pt_init()
        }
        
        if !build_physrw_primitive() {
            Logger.log("构建硬件读写条件失败", type: .error)
            return false
        }
        
        if device.isArm64e {
            if !dmaFail.deinitialise() {
                Logger.log("初始�?\(dmaFail.name) 失败", type: .error)
                return false
            }
        }
        
        if !exploit.deinitialise() {
            Logger.log("初始�?\(exploit.name) 失败", type: .error)
            return false
        }
        
        Logger.log("正在解除沙盒")
        if !unsandbox() {
            Logger.log("解除沙盒失败", type: .error)
            return false
        }
        
        Logger.log("提升权限")
        if !get_root_pplrw() {
            Logger.log("提升权限失败", type: .error)
            return false
        }
        if !platformise() {
            Logger.log("平台化失�?, type: .error)
            return false
        }
    } else {
        
        Logger.log("解除沙盒并提升权限中")
        if !get_root_krw(iOS14) {
            Logger.log("解除沙盒并提升权限失�?, type: .error)
            return false
        }
    }
    
    remount_private_preboot()
    
    if let data = trollstoreTarData {
        do {
            try FileManager.default.createDirectory(atPath: "/private/preboot/tmp", withIntermediateDirectories: false)
            FileManager.default.createFile(atPath: "/private/preboot/tmp/TrollStore.tar", contents: nil)
            try data.write(to: URL(string: "file:///private/preboot/tmp/TrollStore.tar")!)
        } catch {
            print("无法成功写出 TrollStore.tar - \(error.localizedDescription)")
        }
    }
    
    // Prevents download finishing between extraction and installation
    let useLocalCopy = FileManager.default.fileExists(atPath: "/private/preboot/tmp/TrollStore.tar")

    if !fileManager.fileExists(atPath: "/private/preboot/tmp/trollstorehelper") {
        Logger.log("正在获取 TrollStore.tar")
        if !extractTrollStore(useLocalCopy) {
            Logger.log("获取 TrollStore.tar 失败", type: .error)
            return false
        }
    }
    
    let newCandidates = getCandidates()
    persistenceHelperCandidates = newCandidates
    
    // 自动尝试安装持久性助�?
    if !tryInstallPersistenceHelper(newCandidates) {
        Logger.log("无法安装持久性助�?, type: .error)
    }
    
    Logger.log("正在安装 TrollStore")
    if !install_trollstore(useLocalCopy ? "/private/preboot/tmp/TrollStore.tar" : Bundle.main.bundlePath + "/TrollStore.tar") {
        Logger.log("安装 TrollStore 失败", type: .error)
    } else {
        Logger.log("成功安装 TrollStore�?, type: .success)
        Logger.log("巨魔已安装成功，返回桌面查找大头巨魔�?, type: .success)
        Logger.log("如无显示，请在桌面右滑到资源库，�?troll（没有的话重启一下）", type: .warning)
    }
    
    if !cleanupPrivatePreboot() {
        Logger.log("清除 /private/preboot 失败", type: .error)
    }
    
    if !supportsFullPhysRW {
        if !drop_root_krw(iOS14) {
            Logger.log("降低root权限失败", type: .error)
            return false
        }
        if !exploit.deinitialise() {
            Logger.log("初始�?\(exploit.name) 失败", type: .error)
            return false
        }
    }
    
    return true
}

func doIndirectInstall(_ device: Device) async -> Bool {
    let exploit = selectExploit(device)
    
    Logger.log("正运行在 \(device.modelIdentifier) 设备上的 iOS 版本�?\(device.version.readableString)")
    
    if !extractTrollStoreIndirect() {
        return false
    }
    defer {
        cleanupIndirectInstall()
    }
    
    if !(getKernel(device)) {
        Logger.log("获取内核失败", type: .error)
    }
    
    Logger.log("正在查找内核漏洞")
    if !robustInitialiseKernelInfo(kernelPath, false) {
        Logger.log("查找内核漏洞失败", type: .error)
        return false
    }
    
    Logger.log("正在利用内核漏洞 (\(exploit.name))")
    if !exploit.initialise() {
        Logger.log("利用内核漏洞失败", type: .error)
        return false
    }
    defer {
        if !exploit.deinitialise() {
            Logger.log("初始�?\(exploit.name) 失败", type: .error)
        }
    }
    Logger.log("成功利用内核", type: .success)
    post_kernel_exploit(false)
    
    let apps = get_installed_apps() as? [String]
    var candidates = [InstalledApp]()
    for app in apps ?? [String]() {
        print(app)
        for candidate in persistenceHelperCandidates {
            if app.components(separatedBy: "/")[1].replacingOccurrences(of: ".app", with: "") == candidate.bundleName {
                candidates.append(candidate)
                candidates[candidates.count - 1].isInstalled = true
                candidates[candidates.count - 1].bundlePath = "/var/containers/Bundle/Application/" + app
            }
        }
    }
    
    persistenceHelperCandidates = candidates
    
    // 自动选择第一个可用的应用作为持久性助�?
    if let firstCandidate = candidates.first {
        Logger.log("正在自动注入持久性助手到 \(firstCandidate.displayName)")
        let pathToInstall = firstCandidate.bundlePath!
        var success = false
        if !install_persistence_helper_via_vnode(pathToInstall) {
            Logger.log("安装持久性助手失�?, type: .error)
            Logger.log("重启手机后，请再来点击安装！", type: .warning)
            Logger.log("5秒后注销...", type: .warning)
            DispatchQueue.global().async {
                sleep(5)
                restartBackboard()
            }
        } else {
            Logger.log("成功安装持久性助�?, type: .success)
            Logger.log("返回桌面打开\"\(firstCandidate.displayName)\"这个软件。（找不到这个软件，桌面上搜一下。）", type: .warning)
            success = true
        }
        
        if success {
            let verbose = TIXDefaults().bool(forKey: "verbose")
            Logger.log("\(verbose ? "15" : "5") 秒后注销")
            DispatchQueue.global().async {
                sleep(verbose ? 15 : 5)
                restartBackboard()
            }
        }
        return true
    }
    
    Logger.log("未找到可用的应用来安装持久性助�?, type: .error)
    return false
}
