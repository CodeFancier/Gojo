import XCTest
@testable import GojoCore

final class WorkspaceManagerTests: XCTestCase {
    private func makeManager(base: URL) -> WorkspaceManager {
        WorkspaceManager(configStore: ConfigStore(baseDirectory: base))
    }

    func testSetPublicSpaceAndAddRepo() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        let publicSpace = sandbox.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicSpace, withIntermediateDirectories: true)

        let mgr = makeManager(base: try TestSupport.makeTempDir())
        try mgr.setPublicSpace(publicSpace)
        try mgr.addPublicRepo(url: source.path)

        let repos = try mgr.publicRepos()
        XCTAssertEqual(repos.map { $0.lastPathComponent }, ["lib"])
    }

    func testCreateSpaceProjectAndSymlink() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        let publicSpace = sandbox.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicSpace, withIntermediateDirectories: true)
        let base = try TestSupport.makeTempDir()
        let mgr = makeManager(base: base)
        try mgr.setPublicSpace(publicSpace)
        try mgr.addPublicRepo(url: source.path)   // → public/lib

        // 编码空间
        let wsRoot = sandbox.appendingPathComponent("电商中台")
        try mgr.createCodingSpace(name: "电商中台", at: wsRoot)
        XCTAssertTrue(ConfigStore(baseDirectory: base).loadIndex()
            .codingSpacePaths.contains(wsRoot.path))

        // 开发项目（新建子文件夹）
        let projRoot = try mgr.createDevProject(name: "订单", in: wsRoot, existingFolder: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: projRoot.path))

        // 项目内克隆一个 git 仓库
        try mgr.addRepo(url: source.path, subdirectory: "lib-copy", to: projRoot)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projRoot.appendingPathComponent("lib-copy/README.md").path))

        // 软链接公共库
        try mgr.addSymlink(publicRepoName: "lib", linkName: "shared-lib", in: projRoot)
        let link = projRoot.appendingPathComponent("shared-lib")
        XCTAssertFalse(SymlinkService().isBroken(link))

        // 清单已记录
        let manifest = try ConfigStore(baseDirectory: base).loadProject(at: projRoot)
        XCTAssertEqual(manifest?.repos.count, 1)
        XCTAssertEqual(manifest?.symlinks.first?.publicRepoName, "lib")
    }
}
