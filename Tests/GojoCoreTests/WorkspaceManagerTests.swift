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

    func testPublicProjectsAutoDetectsScannedRepo() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        // 直接在公共空间放一个已 clone 的库（不经 addPublicProject）
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        try GitService().clone(url: source.path, into: publicSpace.appendingPathComponent("manual"))

        let projects = try mgr.publicProjects()
        XCTAssertTrue(projects.contains { $0.name == "manual" && $0.cloned })
    }

    func testCompositePublicFolderDiscoversNestedRepositories() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let suite = publicSpace.appendingPathComponent("commerce")
        try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
        try TestSupport.makeLocalGitRepo(named: "orders", in: suite)
        try FileManager.default.createDirectory(
            at: suite.appendingPathComponent("notes"), withIntermediateDirectories: true)

        let folders = try mgr.publicCompositeFolders()

        XCTAssertEqual(folders.map(\.name), ["commerce"])
        XCTAssertEqual(folders[0].projects.map(\.name), ["orders"])
        XCTAssertNil(folders[0].projects[0].publicProjectID)
    }

    func testEveryClonedPublicProjectIsExpandableAndDiscoversChildren() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        let parent = try TestSupport.makeLocalGitRepo(named: "platform", in: publicSpace)
        try TestSupport.makeLocalGitRepo(named: "payments", in: parent)
        let publicProject = try XCTUnwrap(
            mgr.publicProjects().first(where: { $0.name == "platform" })
        )

        let folder = try XCTUnwrap(
            mgr.publicCompositeFolders().first(where: { $0.publicProjectID == publicProject.id })
        )

        XCTAssertEqual(folder.relativePath, "platform")
        XCTAssertEqual(folder.projects.map(\.name), ["payments"])
        XCTAssertEqual(folder.projects[0].parentRelativePath, "platform")
    }

    func testClonedPublicProjectWithoutChildrenIsStillExpandable() throws {
        let (mgr, publicSpace, _) = try makeWithPublicSpace()
        try TestSupport.makeLocalGitRepo(named: "platform", in: publicSpace)
        let publicProject = try XCTUnwrap(
            mgr.publicProjects().first(where: { $0.name == "platform" })
        )

        let folder = try XCTUnwrap(
            mgr.publicCompositeFolders().first(where: { $0.publicProjectID == publicProject.id })
        )

        XCTAssertTrue(folder.projects.isEmpty)
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
        XCTAssertEqual(try mgr.publicCompositeFolders()[0].projects[0].publicProjectID, project.id)
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
            mgr.publicCompositeFolders().first(where: { $0.publicProjectID == ordersProject.id })
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

    // MARK: - 编码空间删除

    func testUnregisterCodingSpaceKeepsFolderAndContents() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try "keep".write(to: ws.appendingPathComponent("keep.txt"),
                         atomically: true, encoding: .utf8)

        try mgr.removeCodingSpace(at: ws, mode: .unregisterOnly)

        XCTAssertTrue(FileManager.default.fileExists(atPath: ws.appendingPathComponent("keep.txt").path))
        XCTAssertFalse(mgr.codingSpaceURLs().contains(ws))
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
        XCTAssertFalse(mgr.codingSpaceURLs().contains(ws))
    }

    func testRemoveCodingSpaceDirectoryDeletesRootFolder() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        try mgr.removeCodingSpace(at: ws, mode: .directory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: ws.path))
        XCTAssertFalse(mgr.codingSpaceURLs().contains(ws))
    }

    func testRemoveCodingSpaceDirectorySucceedsWhenFolderIsAlreadyMissing() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try FileManager.default.removeItem(at: ws)

        XCTAssertNoThrow(try mgr.removeCodingSpace(at: ws, mode: .directory))
        XCTAssertFalse(mgr.codingSpaceURLs().contains(ws))
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
        XCTAssertFalse(mgr.codingSpaceURLs().contains(ws))
    }
}
