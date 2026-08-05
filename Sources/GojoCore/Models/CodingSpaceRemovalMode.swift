import Foundation

public enum CodingSpaceRemovalMode: Hashable {
    /// 仅从 Gojo 的编码空间列表移除，不修改磁盘内容。
    case unregisterOnly
    /// 清空编码空间内的所有内容，但保留根文件夹。
    case contents
    /// 删除编码空间根文件夹及其中的所有内容。
    case directory
}
