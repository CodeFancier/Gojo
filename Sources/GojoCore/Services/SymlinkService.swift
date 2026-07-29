import Foundation

public struct SymlinkService {
    private let fm = FileManager.default
    public init() {}

    /// 在 linkURL 处创建指向 targetURL 的符号链接（绝对路径）。
    public func createSymlink(at linkURL: URL, pointingTo targetURL: URL) throws {
        try fm.createDirectory(at: linkURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)
    }

    /// 是符号链接且目标不存在 → 断链。
    public func isBroken(_ linkURL: URL) -> Bool {
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: linkURL.path)
        else { return false }
        let target = dest.hasPrefix("/")
            ? URL(fileURLWithPath: dest)
            : linkURL.deletingLastPathComponent().appendingPathComponent(dest)
        return !fm.fileExists(atPath: target.path)
    }
}
