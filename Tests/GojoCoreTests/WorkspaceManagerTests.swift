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

    func testRemoveUnclonedPublicProjectRemovesDefinition() throws {
        let (mgr, _, _) = try makeWithPublicSpace()
        try mgr.addPublicProject(name: "lib", url: "git@x:lib.git")
        let id = try XCTUnwrap(mgr.publicProjects().first?.id)

        try mgr.removePublicProject(id: id)

        XCTAssertTrue(try mgr.publicProjects().isEmpty)
    }

    func testRemovePublicProjectRefusesProjectUsedByCodingSpace() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try XCTUnwrap(mgr.publicProjects().first?.id)
        let workspace = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: workspace)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .git, in: workspace)

        XCTAssertThrowsError(try mgr.removePublicProject(id: id)) {
            XCTAssertEqual($0 as? WorkspaceError, .publicProjectInUse("lib"))
        }
        XCTAssertNotNil(try mgr.publicProjects().first(where: { $0.id == id }))
    }

    func testScannedRepoIsNotAutoRegisteredButListedAsGitEntry() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        // 直接在公共空间放一个已 clone 的库（不经 addPublicProject / promote）
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        try GitService().clone(url: source.path, into: publicSpace.appendingPathComponent("manual"))

        // 不自动登记：磁盘=事实，登记=语义，须显式「转为公共仓库」
        XCTAssertFalse(try mgr.publicProjects().contains { $0.name == "manual" })

        let entry = try XCTUnwrap(
            try mgr.publicSpaceEntries().first(where: { $0.relativePath == "manual" })
        )
        XCTAssertTrue(entry.isOnDisk)
        XCTAssertTrue(entry.isGitRepository)
        XCTAssertEqual(entry.remoteURL, source.path)
        XCTAssertNil(entry.publicProjectID)
    }

    func testPublicSpaceEntriesListAllDirectoriesAndDiscoverNestedRepositories() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let suite = publicSpace.appendingPathComponent("commerce")
        try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
        try TestSupport.makeLocalGitRepo(named: "orders", in: suite)
        try FileManager.default.createDirectory(
            at: suite.appendingPathComponent("notes"), withIntermediateDirectories: true)
        // 不含任何 git 子仓库的普通目录也在列表中
        try FileManager.default.createDirectory(
            at: publicSpace.appendingPathComponent("docs"), withIntermediateDirectories: true)

        let entries = try mgr.publicSpaceEntries()

        XCTAssertEqual(entries.map(\.relativePath), ["commerce", "docs"])
        XCTAssertEqual(entries[0].projects.map(\.name), ["orders"])
        XCTAssertNil(entries[0].projects[0].publicProjectID)
        XCTAssertFalse(entries[0].isGitRepository)    // commerce 本身非 git 仓库
        XCTAssertTrue(entries[1].isOnDisk)
        XCTAssertFalse(entries[1].isGitRepository)
        XCTAssertTrue(entries[1].projects.isEmpty)
    }

    func testEveryClonedPublicProjectIsExpandableAndDiscoversChildren() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let parent = try TestSupport.makeLocalGitRepo(named: "platform", in: publicSpace)
        try TestSupport.makeLocalGitRepo(named: "payments", in: parent)
        try mgr.promotePublicProject(relativePath: "platform")
        let publicProject = try XCTUnwrap(
            mgr.publicProjects().first(where: { $0.name == "platform" })
        )

        let entry = try XCTUnwrap(
            try mgr.publicSpaceEntries().first(where: { $0.publicProjectID == publicProject.id })
        )

        XCTAssertEqual(entry.relativePath, "platform")
        XCTAssertTrue(entry.isGitRepository)
        XCTAssertEqual(entry.projects.map(\.name), ["payments"])
        XCTAssertEqual(entry.projects[0].parentRelativePath, "platform")
    }

    func testClonedPublicProjectWithoutChildrenIsStillExpandable() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        try TestSupport.makeLocalGitRepo(named: "platform", in: publicSpace)
        try mgr.promotePublicProject(relativePath: "platform")
        let publicProject = try XCTUnwrap(
            mgr.publicProjects().first(where: { $0.name == "platform" })
        )

        let entry = try XCTUnwrap(
            try mgr.publicSpaceEntries().first(where: { $0.publicProjectID == publicProject.id })
        )

        XCTAssertTrue(entry.projects.isEmpty)
    }

    func testPromoteNestedRepositoryKeepsFilesInPlaceAndRegistersPublicProject() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let suite = publicSpace.appendingPathComponent("commerce")
        try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
        let nested = try TestSupport.makeLocalGitRepo(named: "orders", in: suite)

        try mgr.promoteNestedPublicProject(parentFolderName: "commerce", projectName: "orders")

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
        let project = try XCTUnwrap(mgr.publicProjects().first { $0.name == "orders" })
        XCTAssertTrue(project.cloned)
        XCTAssertEqual(project.relativePath, "commerce/orders")
        XCTAssertEqual(try mgr.publicSpaceEntries()
            .first(where: { $0.relativePath == "commerce" })?
            .projects[0].publicProjectID, project.id)
    }

    func testPromotePublicProjectRegistersTopLevelRepositoryInPlace() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let repo = try TestSupport.makeLocalGitRepo(named: "solo", in: publicSpace)

        try mgr.promotePublicProject(relativePath: "solo")

        XCTAssertTrue(FileManager.default.fileExists(atPath: repo.path))   // 原位不动
        let project = try XCTUnwrap(mgr.publicProjects().first { $0.name == "solo" })
        XCTAssertTrue(project.cloned)
        XCTAssertEqual(project.relativePath, "solo")
        XCTAssertEqual(project.url, "")    // 无 origin 时降级为空串
        let entry = try XCTUnwrap(
            try mgr.publicSpaceEntries().first(where: { $0.relativePath == "solo" })
        )
        XCTAssertEqual(entry.publicProjectID, project.id)
        XCTAssertTrue(entry.isGitRepository)
    }

    func testPublicSpaceEntriesIncludeRegisteredButNotClonedProject() throws {
        let (mgr, _, _) = try makeWithPublicSpace()
        try mgr.addPublicProject(name: "lib", url: "git@x:lib.git")

        let entry = try XCTUnwrap(
            try mgr.publicSpaceEntries().first(where: { $0.relativePath == "lib" })
        )

        XCTAssertFalse(entry.isOnDisk)
        XCTAssertFalse(entry.isGitRepository)
        XCTAssertNotNil(entry.publicProjectID)
        XCTAssertTrue(entry.projects.isEmpty)
    }

    func testPromotePublicProjectRejectsPlainDirectory() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        try FileManager.default.createDirectory(
            at: publicSpace.appendingPathComponent("docs"), withIntermediateDirectories: true)

        XCTAssertThrowsError(try mgr.promotePublicProject(relativePath: "docs")) {
            XCTAssertEqual($0 as? WorkspaceError, .nestedPublicProjectNotFound("docs"))
        }
        XCTAssertTrue(try mgr.publicProjects().isEmpty)
    }

    func testPromotePublicProjectRejectsNameCollision() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        // 已登记名为 lib 的项目（路径 lib，未克隆）；另一个同名仓库嵌在 commerce 下，
        // 路径不同但名称相同——登记名全局唯一，须拒绝。
        try mgr.addPublicProject(name: "lib", url: "git@x:other-lib.git")
        let suite = publicSpace.appendingPathComponent("commerce")
        try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
        try TestSupport.makeLocalGitRepo(named: "lib", in: suite)

        XCTAssertThrowsError(
            try mgr.promoteNestedPublicProject(parentRelativePath: "commerce", projectName: "lib")
        ) {
            XCTAssertEqual($0 as? WorkspaceError, .publicProjectNameCollision("lib"))
        }
    }

    func testPromotedNestedRepositoryCanBeLinkedIntoCodingSpace() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        let suite = publicSpace.appendingPathComponent("commerce")
        try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
        let nested = try TestSupport.makeLocalGitRepo(named: "orders", in: suite)
        try mgr.promoteNestedPublicProject(parentFolderName: "commerce", projectName: "orders")
        let project = try XCTUnwrap(mgr.publicProjects().first { $0.name == "orders" })
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        try mgr.addPublicProjectToSpace(projectId: project.id, mode: .symlink, in: ws)

        let destination = try FileManager.default.destinationOfSymbolicLink(
            atPath: ws.appendingPathComponent("orders").path)
        XCTAssertEqual(URL(fileURLWithPath: destination).standardizedFileURL,
                       nested.standardizedFileURL)
    }

    func testChildOfPromotedProjectCanAlsoBecomePublicProject() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let suite = publicSpace.appendingPathComponent("commerce")
        try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
        let orders = try TestSupport.makeLocalGitRepo(named: "orders", in: suite)
        try TestSupport.makeLocalGitRepo(named: "payments", in: orders)
        try mgr.promoteNestedPublicProject(
            parentRelativePath: "commerce", projectName: "orders")

        let ordersProject = try XCTUnwrap(
            mgr.publicProjects().first(where: { $0.name == "orders" })
        )
        let ordersFolder = try XCTUnwrap(
            mgr.publicSpaceEntries().first(where: { $0.publicProjectID == ordersProject.id })
        )
        XCTAssertEqual(ordersFolder.projects.map(\.name), ["payments"])

        try mgr.promoteNestedPublicProject(
            parentRelativePath: "commerce/orders", projectName: "payments")

        let payments = try XCTUnwrap(
            mgr.publicProjects().first(where: { $0.name == "payments" })
        )
        XCTAssertEqual(payments.relativePath, "commerce/orders/payments")
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

    // MARK: - 扁平成员分支/同步

    func testBranchListAndCheckoutOnMember() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        _ = try ShellRunner().run("git", ["branch", "feature"], cwd: source)

        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try GitService().clone(url: source.path, into: ws.appendingPathComponent("lib"))

        XCTAssertTrue(try mgr.listBranches(folderName: "lib", in: ws).contains("feature"))
        try mgr.setBranch("feature", folderName: "lib", in: ws)
        XCTAssertEqual(try mgr.scanMembers(in: ws).first?.branch, "feature")
    }

    func testSyncMemberDoesNotThrow() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try GitService().clone(url: source.path, into: ws.appendingPathComponent("lib"))
        XCTAssertNoThrow(try mgr.syncMember(folderName: "lib", in: ws))
    }

    // MARK: - 成员跨空间移动

    // 建两个编码空间 ws1 / ws2，返回 (mgr, ws1, ws2, sandbox)
    private func makeTwoSpaces() throws -> (WorkspaceManager, URL, URL, URL) {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws1 = sandbox.appendingPathComponent("ws1")
        let ws2 = sandbox.appendingPathComponent("ws2")
        try mgr.createCodingSpace(name: "ws1", at: ws1)
        try mgr.createCodingSpace(name: "ws2", at: ws2)
        return (mgr, ws1, ws2, sandbox)
    }

    func testMoveStandaloneMemberMovesFolderNoBinding() throws {
        let (mgr, ws1, ws2, sandbox) = try makeTwoSpaces()
        let source = try TestSupport.makeLocalGitRepo(named: "s", in: sandbox)
        try GitService().clone(url: source.path, into: ws1.appendingPathComponent("solo"))

        try mgr.moveMember(folderName: "solo", from: ws1, to: ws2)

        XCTAssertEqual(try mgr.scanMembers(in: ws1).count, 0)
        let moved = try mgr.scanMembers(in: ws2)
        XCTAssertEqual(moved.map { $0.folderName }, ["solo"])
        XCTAssertEqual(moved.first?.form, .standalone)
    }

    func testMovePublicGitMemberMigratesBinding() throws {
        let (mgr, ws1, ws2, sandbox) = try makeTwoSpaces()
        let repo = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: repo.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        try mgr.addPublicProjectToSpace(projectId: id, mode: .git, in: ws1)

        try mgr.moveMember(folderName: "lib", from: ws1, to: ws2)

        XCTAssertEqual(try mgr.scanMembers(in: ws1).count, 0)
        // 绑定随之迁移：目标空间仍识别为 publicGit
        XCTAssertEqual(try mgr.scanMembers(in: ws2).first?.form, .publicGit(id))
    }

    func testMoveSymlinkMemberStillResolves() throws {
        let (mgr, ws1, ws2, sandbox) = try makeTwoSpaces()
        let repo = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: repo.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        try mgr.clonePublicProject(id: id)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws1)

        try mgr.moveMember(folderName: "lib", from: ws1, to: ws2)

        // 绝对路径符号链接移动后仍可解析、仍被识别为 symlink
        let moved = try mgr.scanMembers(in: ws2)
        XCTAssertEqual(moved.first?.form, .publicSymlink(id))
        XCTAssertFalse(SymlinkService().isBroken(ws2.appendingPathComponent("lib")))
    }

    func testMoveMemberNameCollisionThrows() throws {
        let (mgr, ws1, ws2, sandbox) = try makeTwoSpaces()
        let repo = try TestSupport.makeLocalGitRepo(named: "dup", in: sandbox)
        try GitService().clone(url: repo.path, into: ws1.appendingPathComponent("dup"))
        try GitService().clone(url: repo.path, into: ws2.appendingPathComponent("dup"))

        XCTAssertThrowsError(try mgr.moveMember(folderName: "dup", from: ws1, to: ws2)) {
            XCTAssertEqual($0 as? WorkspaceError, .memberNameCollision("dup"))
        }
        // 失败后源仍在
        XCTAssertEqual(try mgr.scanMembers(in: ws1).first?.folderName, "dup")
    }

    // MARK: - 成员删除

    func testRemoveMemberDeletesCurrentFolderAndAllChildren() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        let repo = try TestSupport.makeLocalGitRepo(named: "solo", in: ws)
        let nested = repo.appendingPathComponent("Sources/Feature")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "code".write(to: nested.appendingPathComponent("File.swift"),
                         atomically: true, encoding: .utf8)

        try mgr.removeMember(folderName: "solo", in: ws)

        XCTAssertFalse(FileManager.default.fileExists(atPath: repo.path))
        XCTAssertTrue(try mgr.scanMembers(in: ws).isEmpty)
    }

    func testRemoveSymlinkMemberDoesNotDeletePublicRepository() throws {
        let (mgr, ws, _, _) = try setupSymlinkMember()
        let target = try mgr.publicSpaceURL().appendingPathComponent("lib")

        try mgr.removeMember(folderName: "lib", in: ws)

        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try mgr.scanMembers(in: ws).isEmpty)
    }

    // MARK: - 编码空间根目录

    func testSetAndClearCodingSpaceRoot() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let root = sandbox.appendingPathComponent("spaces")

        try mgr.setCodingSpaceRoot(root)
        XCTAssertEqual(mgr.codingSpaceRootURL()?.path, root.path)

        try mgr.clearCodingSpaceRoot()
        XCTAssertNil(mgr.codingSpaceRootURL())
    }

    func testUniqueCodingSpaceFolderName() throws {
        let dir = try TestSupport.makeTempDir()
        XCTAssertEqual(WorkspaceManager.uniqueCodingSpaceFolderName(base: "ws", in: dir), "ws")

        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("ws"), withIntermediateDirectories: true)
        XCTAssertEqual(WorkspaceManager.uniqueCodingSpaceFolderName(base: "ws", in: dir), "ws_2")

        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("ws_2"), withIntermediateDirectories: true)
        XCTAssertEqual(WorkspaceManager.uniqueCodingSpaceFolderName(base: "ws", in: dir), "ws_3")

        // 同名文件同样占名；usedNames 仅内存判重（磁盘无冲突时也生效）
        try "f".write(to: dir.appendingPathComponent("app"), atomically: true, encoding: .utf8)
        XCTAssertEqual(WorkspaceManager.uniqueCodingSpaceFolderName(base: "app", in: dir), "app_2")
        XCTAssertEqual(WorkspaceManager.uniqueCodingSpaceFolderName(
            base: "lib", in: dir, usedNames: ["lib"]), "lib_2")
    }

    func testCreateCodingSpaceUnderRootCreatesFolderAndRegisters() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let root = sandbox.appendingPathComponent("spaces")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let url = try mgr.createCodingSpace(named: "电商中台", underRoot: root)

        XCTAssertEqual(url.path, root.appendingPathComponent("电商中台").path)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: url.appendingPathComponent(".gojo/workspace.json").path))
        // 用 path 比较：macOS Foundation 的 URL == 对不同构造来源的 file URL 判不等
        XCTAssertTrue(mgr.codingSpaceURLs().map(\.path).contains(url.path),
                      "codingSpaceURLs: \(mgr.codingSpaceURLs().map(\.path))")
    }

    func testCreateCodingSpaceUnderRootDedupesExistingFolder() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let root = sandbox.appendingPathComponent("spaces")
        let existing = root.appendingPathComponent("ws")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        try "哨兵".write(to: existing.appendingPathComponent("sentinel.txt"),
                        atomically: true, encoding: .utf8)

        let url = try mgr.createCodingSpace(named: "ws", underRoot: root)

        // 已有同名目录不动，新建 ws_2，且清单名 = 实际文件夹名
        XCTAssertEqual(url.lastPathComponent, "ws_2")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: existing.appendingPathComponent("sentinel.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: existing.appendingPathComponent(".gojo").path))
    }

    func testExistingProjectFoldersListsUnregisteredDirectories() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let root = sandbox.appendingPathComponent("spaces")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("beta"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("alpha/.git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".hidden"), withIntermediateDirectories: true)
        try "f".write(to: root.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let folders = try mgr.existingProjectFolders(underRoot: root)

        // 隐藏目录与文件不列；按名排序；.git 只作徽标不影响收录
        XCTAssertEqual(folders.map { $0.name }, ["alpha", "beta"])
        XCTAssertEqual(folders.first { $0.name == "alpha" }?.isGitRepository, true)
        XCTAssertEqual(folders.first { $0.name == "beta" }?.isGitRepository, false)
    }

    func testExistingProjectFoldersExcludesRegisteredCodingSpaces() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let root = sandbox.appendingPathComponent("spaces")
        let ws = root.appendingPathComponent("ws")
        try FileManager.default.createDirectory(at: ws, withIntermediateDirectories: true)
        try mgr.createCodingSpace(name: "ws", at: ws)   // 已登记为编码空间

        XCTAssertTrue(try mgr.existingProjectFolders(underRoot: root).isEmpty)
    }

    func testSanitizedFolderName() {
        XCTAssertEqual(WorkspaceManager.sanitizedFolderName("  a/b  "), "a-b")
        XCTAssertEqual(WorkspaceManager.sanitizedFolderName("a:b"), "a-b")
        XCTAssertEqual(WorkspaceManager.sanitizedFolderName(".hidden"), "hidden")
        XCTAssertEqual(WorkspaceManager.sanitizedFolderName("..."), "")
        XCTAssertEqual(WorkspaceManager.sanitizedFolderName("   "), "")
        XCTAssertEqual(WorkspaceManager.sanitizedFolderName("正常名称"), "正常名称")
    }

    // MARK: - 编码空间删除

    func testUnregisterCodingSpaceKeepsFolderAndContents() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try "keep".write(to: ws.appendingPathComponent("keep.txt"),
                         atomically: true, encoding: .utf8)

        try mgr.removeCodingSpace(at: ws, mode: .unregisterOnly)

        XCTAssertTrue(FileManager.default.fileExists(atPath: ws.appendingPathComponent("keep.txt").path))
        XCTAssertFalse(mgr.codingSpaceURLs().map(\.path).contains(ws.path))
    }

    func testRemoveCodingSpaceContentsKeepsEmptyRootFolder() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.createDirectory(
            at: ws.appendingPathComponent("project/nested"), withIntermediateDirectories: true)

        try mgr.removeCodingSpace(at: ws, mode: .contents)

        XCTAssertTrue(FileManager.default.fileExists(atPath: ws.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: ws.path).isEmpty)
        XCTAssertFalse(mgr.codingSpaceURLs().map(\.path).contains(ws.path))
    }

    func testRemoveCodingSpaceDirectoryDeletesRootFolder() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        try mgr.removeCodingSpace(at: ws, mode: .directory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: ws.path))
        XCTAssertFalse(mgr.codingSpaceURLs().map(\.path).contains(ws.path))
    }

    func testRemoveCodingSpaceDirectorySucceedsWhenFolderIsAlreadyMissing() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.removeItem(at: ws)

        XCTAssertNoThrow(try mgr.removeCodingSpace(at: ws, mode: .directory))
        XCTAssertFalse(mgr.codingSpaceURLs().map(\.path).contains(ws.path))
    }

    func testRemovalItemsAreEmptyWhenCodingSpaceFolderIsAlreadyMissing() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.removeItem(at: ws)

        XCTAssertTrue(try mgr.codingSpaceRemovalItems(at: ws).isEmpty)
    }

    func testRemoveCodingSpaceRefusesFileSystemRoot() throws {
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        var index = store.loadIndex()
        index.codingSpacePaths = ["/"]
        try store.saveIndex(index)
        let mgr = WorkspaceManager(configStore: store)

        XCTAssertThrowsError(try mgr.removeCodingSpace(
            at: URL(fileURLWithPath: "/"), mode: .directory)) {
            XCTAssertEqual($0 as? WorkspaceError, .unsafeCodingSpacePath("/"))
        }
        XCTAssertEqual(mgr.codingSpaceURLs().map(\.path), ["/"])
    }

    func testCodingSpaceRemovalItemsListChildFoldersThenCurrentFolder() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.createDirectory(
            at: ws.appendingPathComponent("orders/nested"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: ws.appendingPathComponent("accounts"), withIntermediateDirectories: true)
        try "keep with root".write(to: ws.appendingPathComponent("notes.txt"),
                                   atomically: true, encoding: .utf8)

        let items = try mgr.codingSpaceRemovalItems(at: ws)

        XCTAssertEqual(items.map(\.name), ["accounts", "orders", "ws"])
        XCTAssertEqual(items.map(\.isRoot), [false, false, true])
    }

    func testRemovalItemsContainRootWhenAllProjectFoldersAreMissing() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        let items = try mgr.codingSpaceRemovalItems(at: ws)

        XCTAssertEqual(items.map(\.name), ["ws"])
        XCTAssertEqual(items.map(\.isRoot), [true])
    }

    func testRemovalItemsIncludeHiddenFoldersAndRoot() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.createDirectory(
            at: ws.appendingPathComponent(".cache"), withIntermediateDirectories: true)
        try "hidden".write(to: ws.appendingPathComponent(".env"),
                           atomically: true, encoding: .utf8)

        let items = try mgr.codingSpaceRemovalItems(at: ws)

        XCTAssertEqual(items.map(\.name), [".cache", "ws"])
        XCTAssertEqual(items.map(\.isRoot), [false, true])
    }

    func testRegisteredCodingSpaceWithoutManifestCanStillBeRemoved() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.removeItem(at: ws.appendingPathComponent(".gojo"))
        try "hidden".write(to: ws.appendingPathComponent(".env"),
                           atomically: true, encoding: .utf8)

        let items = try mgr.codingSpaceRemovalItems(at: ws)
        XCTAssertEqual(items.map(\.name), ["ws"])

        try mgr.removeCodingSpace(at: ws, mode: .directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ws.path))
        XCTAssertFalse(mgr.codingSpaceURLs().map(\.path).contains(ws.path))
    }

    // MARK: - 外部项目软链接导入

    func testScanMembersRecognizesExternalSymlinkAfterLink() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let external = try TestSupport.makeLocalGitRepo(named: "app", in: sandbox)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        // 软链接导入：不写清单，靠扫描发现为 .externalSymlink
        try mgr.linkExternalProject(into: ws, folderName: "app", target: external)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.folderName, "app")
        guard case .externalSymlink(let target) = members.first?.form else {
            XCTFail("期望 .externalSymlink，得到 \(String(describing: members.first?.form))")
            return
        }
        XCTAssertEqual(target, external.path)
    }

    func testScanMembersRecognizesExternalSymlinkWithoutGit() throws {
        // Claude/Codex 扫描发现的项目常无 .git：导入端不设门槛，
        // 扫描端也必须收录，否则导入“成功”后空间是空壳。
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let plain = sandbox.appendingPathComponent("notes")
        try FileManager.default.createDirectory(
            at: plain.appendingPathComponent("sub"), withIntermediateDirectories: true)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        try mgr.linkExternalProject(into: ws, folderName: "notes", target: plain)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.map { $0.folderName }, ["notes"])
        guard case .externalSymlink(let target) = members.first?.form else {
            XCTFail("期望 .externalSymlink，得到 \(String(describing: members.first?.form))")
            return
        }
        XCTAssertEqual(target, plain.path)
        XCTAssertNil(members.first?.branch)   // 非 git 目标读不到分支
    }

    func testScanMembersSkipsBrokenExternalSymlink() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let external = sandbox.appendingPathComponent("gone")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.linkExternalProject(into: ws, folderName: "gone", target: external)
        try FileManager.default.removeItem(at: external)   // 目标先于扫描被移走

        XCTAssertTrue(try mgr.scanMembers(in: ws).isEmpty)
    }

    func testLinkExternalProjectRefusesNameCollision() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let external = try TestSupport.makeLocalGitRepo(named: "app", in: sandbox)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.linkExternalProject(into: ws, folderName: "app", target: external)

        XCTAssertThrowsError(
            try mgr.linkExternalProject(into: ws, folderName: "app", target: external)
        ) {
            XCTAssertEqual($0 as? WorkspaceError, .memberNameCollision("app"))
        }
    }
}
