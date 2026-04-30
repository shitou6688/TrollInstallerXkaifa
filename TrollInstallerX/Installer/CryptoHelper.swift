//
//  CryptoHelper.swift
//  TrollInstallerX
//
//  TrollStore.tar.enc AES-256-CBC 解密模块
//  加密脚本: encrypt_trollstore.py
//

import Foundation
import CommonCrypto

/// AES-256 密钥（必须和 Python 加密脚本中的 AES_KEY 一致）
private let TROLLSTORE_AES_KEY: Data = Data("jumo-tsx-2024-shitou6688-trolls!".utf8)

/// 解密 TrollStore.tar.enc 并写入临时文件
/// - Returns: 解密后的 tar 文件路径，失败返回 nil
func decryptTarIfNeeded() -> String? {
    // 1. 查找 .enc 文件
    guard let encPath = Bundle.main.path(forResource: "TrollStore", ofType: "tar.enc") else {
        // 没有 .enc，回退到未加密的 .tar
        if let tarPath = Bundle.main.path(forResource: "TrollStore", ofType: "tar") {
            return tarPath
        }
        Logger.log("未找到 TrollStore.tar.enc（加密版）或 TrollStore.tar（未加密版）", type: .error)
        return nil
    }

    // 2. 读取加密文件
    guard let encData = try? Data(contentsOf: URL(fileURLWithPath: encPath)) else {
        Logger.log("读取 TrollStore.tar.enc 失败", type: .error)
        return nil
    }

    // 3. 文件至少 32 字节（16 IV + 16 一个 block）
    if encData.count < 32 {
        Logger.log("TrollStore.tar.enc 文件过小", type: .error)
        return nil
    }

    // 4. 提取 IV（前 16 字节）和密文
    let ivData = encData.prefix(16)
    let cipherData = encData.dropFirst(16)

    // 5. 准备解密缓冲区
    let bufferSize = cipherData.count + kCCBlockSizeAES128
    var buffer = Data(count: bufferSize)

    // 6. AES-256-CBC 解密
    var decryptedSize = 0
    let status = cipherData.withUnsafeBytes { cipherBytes in
        ivData.withUnsafeBytes { ivBytes in
            TROLLSTORE_AES_KEY.withUnsafeBytes { keyBytes in
                buffer.withUnsafeMutableBytes { bufferBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, kCCKeySizeAES256,
                        ivBytes.baseAddress,
                        cipherBytes.baseAddress, cipherData.count,
                        bufferBytes.baseAddress, bufferSize,
                        &decryptedSize
                    )
                }
            }
        }
    }

    // 7. 检查解密状态
    if status != kCCSuccess {
        Logger.log("TrollStore.tar.enc 解密失败（错误码 \(status)）", type: .error)
        return nil
    }

    // 8. 截取有效数据
    buffer.count = decryptedSize
    let decryptedData = buffer

    // 9. 写入临时目录
    let tmpPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].path + "/TrollStore.decrypted"
    do {
        try decryptedData.write(to: URL(fileURLWithPath: tmpPath))
        Logger.log("TrollStore.tar.enc 解密成功（\(decryptedSize) 字节）", type: .success)
        return tmpPath
    } catch {
        Logger.log("写入解密后的 tar 失败: \(error.localizedDescription)", type: .error)
        return nil
    }
}
