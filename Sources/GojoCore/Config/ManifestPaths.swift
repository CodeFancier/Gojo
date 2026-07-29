import Foundation

public enum ManifestPaths {
    public static func gojoDir(in root: URL) -> URL {
        root.appendingPathComponent(".gojo", isDirectory: true)
    }
    public static func workspaceManifest(in root: URL) -> URL {
        gojoDir(in: root).appendingPathComponent("workspace.json")
    }
    public static func publicSpaceManifest(in root: URL) -> URL {
        gojoDir(in: root).appendingPathComponent("public.json")
    }
}
