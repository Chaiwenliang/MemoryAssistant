import Foundation

/// API Key 混淆存储（非绝对安全，上架建议改后端代理）。
///
/// **如何更换 Key：**
/// 1. 终端运行：
///    python3 -c "key='你的新Key'; x=0x5A; print(list(b^x for b in key.encode()))"
/// 2. 把输出的数字数组替换到 `encodedAPIKey`
///
/// **如何更换接口域名：** 改 `LLMConfig.baseURL`
enum LLMSecrets {
    private static let xor: UInt8 = 0x5A
    private static let encodedAPIKey: [UInt8] = [
        41, 49, 119, 63, 107, 98, 104, 106, 63, 108, 98, 110, 107, 111, 109, 110,
        62, 111, 107, 99, 109, 98, 62, 57, 56, 60, 57, 106, 105, 111
    ]

    static var apiKey: String {
        String(bytes: encodedAPIKey.map { $0 ^ xor }, encoding: .utf8) ?? ""
    }
}
