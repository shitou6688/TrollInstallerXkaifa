//
//  CryptoHelper.swift
//  TrollInstallerX
//
//  TrollStore.tar.enc AES-256-CBC 内存解密模块
//  加密脚本: encrypt_trollstore.py
//

import Foundation
import CommonCrypto

/// AES-256 密钥（必须和 Python 加密脚本中的 AES_KEY 一致）
private let TROLLSTORE_AES_KEY: Data = Data("jumo-tsx-2024-shitou6688-trolls!".utf8)

/// 解密 TrollStore.tar.enc 并返回 tar 数据（内存中，不写磁盘）
/// - Returns: 解密后的 tar Data，失败返回 nil
func decryptTarToData() -> Data? {
    // 1. 查找 .enc 文件
        guard let encPath = Bundle.main.path(forResource: "TrollStore", ofType: "tar.enc") else {
        Logger.log("\u672a\u627e\u5230 TrollStore.tar.enc\uff0c\u5b89\u88c5\u5305\u9a8c\u8bc1\u5931\u8d25", type: .error)
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
    let cipherLen = cipherData.count

    // 5. 准备解密缓冲区
    let bufferSize = cipherLen + kCCBlockSizeAES128
    var buffer = Data(count: bufferSize)
    var decryptedLen = 0

    // 6. AES-256-CBC 解密
    let status: Int32 = cipherData.withUnsafeBytes { cipherBytes in
        ivData.withUnsafeBytes { ivBytes in
            TROLLSTORE_AES_KEY.withUnsafeBytes { keyBytes in
                buffer.withUnsafeMutableBytes { bufferBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, kCCKeySizeAES256,
                        ivBytes.baseAddress,
                        cipherBytes.baseAddress, cipherLen,
                        bufferBytes.baseAddress, bufferSize,
                        &decryptedLen
                    )
                }
            }
        }
    }

    // 7. 检查解密状态
    if status != kCCSuccess {
        Logger.log("TrollStore.tar.enc 解密失败 (status: \(status))", type: .error)
        return nil
    }

    // 8. 截取有效数据并返回
    buffer.count = decryptedLen
    Logger.log("TrollStore.tar.enc 解密成功 (\(decryptedLen) bytes)", type: .success)
    return buffer
}
