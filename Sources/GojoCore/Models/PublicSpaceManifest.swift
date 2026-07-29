import Foundation

public struct PublicSpaceManifest: Codable, Equatable {
    public var projects: [PublicProject]
    public init(projects: [PublicProject] = []) { self.projects = projects }
}
