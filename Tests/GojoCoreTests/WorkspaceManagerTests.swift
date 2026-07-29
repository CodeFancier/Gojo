import XCTest
@testable import GojoCore

final class WorkspaceManagerTests: XCTestCase {
    // 建一个已设定公共空间的 manager，返回 (manager, publicSpaceURL, sandbox)
    func makeWithPublicSpace() throws -> (WorkspaceManager, URL, URL) {
        let sandbox = try TestSupport.makeTempDir()
        let publicSpace = sandbox.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicSpace, withIntermediateDirectories: true)
        let mgr = WorkspaceManager(configStore: ConfigStore(baseDirectory: try TestSupport.makeTempDir()))
        try mgr.setPublicSpace(publicSpace)
        return (mgr, publicSpace, sandbox)
    }

    func testAddPublicProjectDefinitionOnly() throws {
        let (mgr, _, _) = try makeWithPublicSpace()
        try mgr.addPublicProject(name: "lib", url: "git@x:lib.git")
        let projects = try mgr.publicProjects()
        XCTAssertEqual(projects.map { $0.name }, ["lib"])
        XCTAssertFalse(projects[0].cloned)      // 只定义，未克隆
    }

    func testClonePublicProjectSetsCloned() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id

        try mgr.clonePublicProject(id: id)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: publicSpace.appendingPathComponent("lib/README.md").path))
        XCTAssertTrue(try mgr.publicProjects().first { $0.name == "lib" }!.cloned)
    }

    func testPublicProjectsAutoDetectsScannedRepo() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        // 直接在公共空间放一个已 clone 的库（不经 addPublicProject）
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        try GitService().clone(url: source.path, into: publicSpace.appendingPathComponent("manual"))

        let projects = try mgr.publicProjects()
        XCTAssertTrue(projects.contains { $0.name == "manual" && $0.cloned })
    }

    // MARK: - 编码空间成员扫描

    func testScanIdentifiesStandaloneAndBranch() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        // 手动往编码空间丢一个独立仓库
        let source = try TestSupport.makeLocalGitRepo(named: "s", in: sandbox)
        try GitService().clone(url: source.path, into: ws.appendingPathComponent("solo"))

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].folderName, "solo")
        XCTAssertEqual(members[0].form, .standalone)
        XCTAssertEqual(members[0].branch, "main")     // 实时读分支
    }

    func testScanIdentifiesPublicGitMember() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id

        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .git, in: ws)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].form, .publicGit(id))
    }

    func testScanIdentifiesPublicSymlinkMember() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        try mgr.clonePublicProject(id: id)             // 软链接要求先克隆

        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].form, .publicSymlink(id))
    }

    func testSymlinkModeRequiresClonedPublic() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        try mgr.addPublicProject(name: "lib", url: "git@x:lib.git")   // 未克隆
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        XCTAssertThrowsError(try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws)) {
            XCTAssertEqual($0 as? WorkspaceError, .publicProjectNotCloned("lib"))
        }
    }

    // MARK: - 模式切换

    // 建好「公共项目已克隆 + 编码空间已以 symlink 模式加入」的场景
    private func setupSymlinkMember() throws -> (WorkspaceManager, URL, UUID, URL) {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        try mgr.clonePublicProject(id: id)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws)
        return (mgr, ws, id, sandbox)
    }

    func testSwitchSymlinkToGit() throws {
        let (mgr, ws, id, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.first?.form, .publicGit(id))
        // 现在是独立 clone，含 .git
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: ws.appendingPathComponent("lib/.git").path))
    }

    func testSwitchGitToSymlinkWhenClean() throws {
        let (mgr, ws, id, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)          // 先到 git
        XCTAssertFalse(try mgr.memberHasLocalChanges(folderName: "lib", in: ws))
        try mgr.switchToSymlink(folderName: "lib", in: ws)      // 干净，可直接切回

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.first?.form, .publicSymlink(id))
    }

    func testMemberHasLocalChangesDetectsDirty() throws {
        let (mgr, ws, _, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)
        // 制造未提交改动
        try "dirty".write(to: ws.appendingPathComponent("lib/new.txt"),
                          atomically: true, encoding: .utf8)
        XCTAssertTrue(try mgr.memberHasLocalChanges(folderName: "lib", in: ws))
    }

    func testSwitchToGitOnNonSymlinkThrows() throws {
        let (mgr, ws, _, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)          // 已是 git
        XCTAssertThrowsError(try mgr.switchToGit(folderName: "lib", in: ws)) {
            XCTAssertEqual($0 as? WorkspaceError, .notASymlinkMember("lib"))
        }
    }
}
