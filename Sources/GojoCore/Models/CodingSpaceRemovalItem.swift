import Foundation

public struct CodingSpaceRemovalItem: Identifiable, Hashable {
    public var name: String
    public var url: URL
    public var isRoot: Bool

    public var id: String { url.path }

    public init(name: String, url: URL, isRoot: Bool) {
        self.name = name
        self.url = url
        self.isRoot = isRoot
    }
}
