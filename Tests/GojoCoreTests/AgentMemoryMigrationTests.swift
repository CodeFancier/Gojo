import XCTest
@testable import GojoCore

/// 记忆转载 + 编码空间重命名编排 + 空间记忆总览的测试。
/// 全部用可注入的临时 home，不碰真实的 ~/.claude 与 ~/.codex。
final class AgentMemoryMigrationTests: XCTestCase {
    private let fm = FileManager.default

    private func claudeProjectDir(_ home: URL, for path: String) -> URL {
        home.appendingPathComponent(".claude/projects", isDirectory: true)
            .appendingPathComponent(AgentMemoryReader.claudeProjectDirName(for: path),
                                    isDirectory: true)
    }

    private func makeClaudeMemory(_ home: URL, projectPath: String,
                                  docs: [String: String] = ["a.md": "# a"],
                                  sessionID: String = "s-1") throws {
        let dir = claudeProjectDir(home, for: projectPath)
        let memory = dir.appendingPathComponent("memory", isDirectory: true)
        try fm.createDirectory(at: memory, withIntermediateDirectories: true)
        for (name, content) in docs {
            try content.write(to: memory.appendingPathComponent(name),
                              atomically: true, encoding: .utf8)
        }
        try "{\"type\":\"ai-title\",\"aiTitle\":\"t\",\"sessionId\":\"\(sessionID)\"}"
            .write(to: dir.appendingPathComponent("\(sessionID).jsonl"),
                   atomically: true, encoding: .utf8)
    }

    @discardableResult
    private func makeCodexSession(_ home: URL, id: String, cwd: String) throws -> URL {
        let dir = home.appendingPathComponent(".codex/sessions/2026/08/21", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("rollout-\(id).jsonl")
        try """
        {"type":"session_meta","payload":{"id":"\(id)","cwd":"\(cwd)"}}
        {"type":"turn_context","payload":{"cwd":"\(cwd)","model":"gpt"}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"问题"}]}}
        """.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    // MARK: Claude 转载

    func testClaudeMigrateMovesProjectDir() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        let new = URL(fileURLWithPath: "/tmp/new-space")
        try makeClaudeMemory(home, projectPath: old.path)

        let results = ClaudeMemoryMigrator(home: home).migrate([(old, new)])
        XCTAssertTrue(results.allSatisfy { !$0.failed })

        let newDir = claudeProjectDir(home, for: new.path)
        XCTAssertTrue(fm.fileExists(atPath: newDir.appendingPathComponent("memory/a.md").path))
        XCTAssertTrue(fm.fileExists(atPath: newDir.appendingPathComponent("s-1.jsonl").path))
        XCTAssertFalse(fm.fileExists(atPath: claudeProjectDir(home, for: old.path).path))
        // 迁移后新路径可读、旧路径不可用。
        let reader = AgentMemoryReader(home: home)
        XCTAssertEqual(reader.snapshot(for: .claude, projectPath: new).memoryDocs.count, 1)
        XCTAssertFalse(reader.snapshot(for: .claude, projectPath: old).available)
    }

    func testClaudeMigrateConflictKeepsBothFiles() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        let new = URL(fileURLWithPath: "/tmp/new-space")
        try makeClaudeMemory(home, projectPath: old.path, docs: ["a.md": "# old"])
        try makeClaudeMemory(home, projectPath: new.path, docs: ["a.md": "# new"])

        let results = ClaudeMemoryMigrator(home: home).migrate([(old, new)])
        XCTAssertTrue(results.allSatisfy { !$0.failed })

        let newMemory = claudeProjectDir(home, for: new.path)
            .appendingPathComponent("memory", isDirectory: true)
        XCTAssertEqual(try String(contentsOf: newMemory.appendingPathComponent("a.md"),
                                  encoding: .utf8), "# new")
        XCTAssertEqual(try String(contentsOf: newMemory.appendingPathComponent("a.migrated.md"),
                                  encoding: .utf8), "# old")
    }

    func testClaudeMigrateIsIdempotent() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        let new = URL(fileURLWithPath: "/tmp/new-space")
        let migrator = ClaudeMemoryMigrator(home: home)

        try makeClaudeMemory(home, projectPath: old.path)
        _ = migrator.migrate([(old, new)])
        let second = migrator.migrate([(old, new)])
        XCTAssertTrue(second.isEmpty, "旧目录已不存在，第二遍无事可做")
    }

    func testClaudePlanCountsDocsAndSessions() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        try makeClaudeMemory(home, projectPath: old.path,
                             docs: ["MEMORY.md": "# i", "b.md": "# b"])
        let plan = ClaudeMemoryMigrator(home: home).plan([
            (old, URL(fileURLWithPath: "/tmp/new-space"))])
        XCTAssertEqual(plan.memoryDocs, 2)
        XCTAssertEqual(plan.sessions, 1)
    }

    // MARK: Codex 转载

    func testCodexMigrateRewritesCWDOnlyForMatchingSessions() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        let new = URL(fileURLWithPath: "/tmp/new-space")
        let hit = try makeCodexSession(home, id: "cs-1", cwd: old.path)
        let miss = try makeCodexSession(home, id: "cs-2", cwd: "/tmp/other")
        let missBefore = try String(contentsOf: miss, encoding: .utf8)

        let results = CodexMemoryMigrator(home: home).migrate([(old, new)])
        XCTAssertTrue(results.allSatisfy { !$0.failed })

        let hitAfter = try String(contentsOf: hit, encoding: .utf8)
        XCTAssertTrue(hitAfter.contains("\"cwd\":\(jsonQuoted(new.path))"))
        XCTAssertFalse(hitAfter.contains(jsonQuoted(old.path)))
        XCTAssertEqual(try String(contentsOf: miss, encoding: .utf8), missBefore,
                       "不匹配的会话保持原字节")
        // 迁移后新路径读得到、旧路径读不到。
        let reader = AgentMemoryReader(home: home)
        XCTAssertEqual(reader.snapshot(for: .codex, projectPath: new).sessions.count, 1)
        XCTAssertEqual(reader.snapshot(for: .codex, projectPath: old).sessions.count, 0)
    }

    func testCodexMigrateIsIdempotent() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        let new = URL(fileURLWithPath: "/tmp/new-space")
        let file = try makeCodexSession(home, id: "cs-1", cwd: old.path)
        let migrator = CodexMemoryMigrator(home: home)

        _ = migrator.migrate([(old, new)])
        let afterFirst = try String(contentsOf: file, encoding: .utf8)
        _ = migrator.migrate([(old, new)])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), afterFirst,
                       "cwd 已是新路径，第二遍零改动")
    }

    func testCodexPlanCountsMatchingSessions() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        try makeCodexSession(home, id: "cs-1", cwd: old.path)
        try makeCodexSession(home, id: "cs-2", cwd: "\(old.path)/member")
        try makeCodexSession(home, id: "cs-3", cwd: "/tmp/other")

        let plan = CodexMemoryMigrator(home: home).plan([
            (old, URL(fileURLWithPath: "/tmp/new-space")),
            (old.appendingPathComponent("member"),
             URL(fileURLWithPath: "/tmp/new-space/member"))])
        XCTAssertEqual(plan.sessions, 2)
    }

    // MARK: 进度回调

    func testMigrateReportsAggregatedProgress() throws {
        let home = try TestSupport.makeTempDir()
        let old = URL(fileURLWithPath: "/tmp/old-space")
        let new = URL(fileURLWithPath: "/tmp/new-space")
        // Claude 一个待迁目录 + Codex 一个命中会话 = 总 2 个单位。
        try makeClaudeMemory(home, projectPath: old.path)
        try makeCodexSession(home, id: "cs-1", cwd: old.path)

        var updates: [AgentMigrationProgress] = []
        let results = AgentMemoryMigrationService(home: home).migrate([(old, new)]) { p in
            updates.append(p)
        }
        XCTAssertTrue(results.allSatisfy { !$0.failed })
        XCTAssertEqual(updates.first, AgentMigrationProgress(completed: 0, total: 2),
                       "开始即报总分母")
        XCTAssertEqual(updates.last, AgentMigrationProgress(completed: 2, total: 2),
                       "结束必达满值")
        XCTAssertTrue(updates.dropFirst().allSatisfy { $0.total == 2 })
        XCTAssertTrue(zip(updates, updates.dropFirst()).allSatisfy { $0.completed + 1 == $1.completed },
                      "逐单位递增")
    }

    func testMigrateProgressTotalZeroWhenNothingToMigrate() throws {
        let home = try TestSupport.makeTempDir()
        var updates: [AgentMigrationProgress] = []
        _ = AgentMemoryMigrationService(home: home).migrate(
            [(URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b"))]) { p in
            updates.append(p)
        }
        XCTAssertEqual(updates, [AgentMigrationProgress(completed: 0, total: 0)])
    }

    /// JSON 字符串字面量形式（JSONSerialization 输出不转义 `/`）。
    private func jsonQuoted(_ s: String) -> String { "\"\(s)\"" }

    // MARK: 受影响路径对

    func testAffectedMovesCoversRootAndChildren() throws {
        let sandbox = try TestSupport.makeTempDir()
        let oldSpace = sandbox.appendingPathComponent("Old")
        try fm.createDirectory(at: oldSpace.appendingPathComponent("memberA"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: oldSpace.appendingPathComponent("memberB"),
                               withIntermediateDirectories: true)
        try "x".write(to: oldSpace.appendingPathComponent("loose.txt"),
                     atomically: true, encoding: .utf8)
        try fm.createDirectory(at: oldSpace.appendingPathComponent(".gojo"),
                               withIntermediateDirectories: true)
        let newSpace = sandbox.appendingPathComponent("New")

        let moves = AgentMemoryMigrationService.affectedMoves(oldSpace: oldSpace, newSpace: newSpace)
        XCTAssertEqual(Set(moves.map(\.old.path)),
                       Set([oldSpace.path,
                            oldSpace.appendingPathComponent("memberA").path,
                            oldSpace.appendingPathComponent("memberB").path,
                            oldSpace.appendingPathComponent("loose.txt").path]),
                       "空间根 + 直接子项都算，.gojo 除外")
    }

    func testAffectedMovesFallsBackToNewSideAfterRename() throws {
        let sandbox = try TestSupport.makeTempDir()
        let oldSpace = sandbox.appendingPathComponent("Old")
        let newSpace = sandbox.appendingPathComponent("New")
        try fm.createDirectory(at: newSpace.appendingPathComponent("member"),
                               withIntermediateDirectories: true)
        // 重命名完成后旧侧已消失：子项列表应从新侧取，映射回旧路径。
        let moves = AgentMemoryMigrationService.affectedMoves(oldSpace: oldSpace, newSpace: newSpace)
        XCTAssertEqual(moves.map(\.old.path), [oldSpace.path,
                                               oldSpace.appendingPathComponent("member").path])
    }

    // MARK: 重命名编排

    private func makeRenamer(home: URL) throws -> (CodingSpaceRenamer, ConfigStore, URL) {
        let sandbox = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        let renamer = CodingSpaceRenamer(configStore: store, home: home)
        let space = sandbox.appendingPathComponent("OldSpace")
        try WorkspaceManager(configStore: store).createCodingSpace(name: "OldSpace", at: space)
        return (renamer, store, space)
    }

    func testRenameMovesFolderAndUpdatesIndexAndManifest() throws {
        let home = try TestSupport.makeTempDir()
        let (renamer, store, space) = try makeRenamer(home: home)

        let outcome = try renamer.rename(space, to: "NewSpace", migrateMemory: false)
        XCTAssertEqual(outcome.newURL.lastPathComponent, "NewSpace")
        XCTAssertFalse(fm.fileExists(atPath: space.path))
        XCTAssertTrue(fm.fileExists(
            atPath: outcome.newURL.appendingPathComponent(".gojo").path))
        XCTAssertEqual(store.loadIndex().codingSpacePaths, [outcome.newURL.path])
        XCTAssertEqual(try store.loadWorkspace(at: outcome.newURL)?.name, "NewSpace")
    }

    func testRenameThrowsOnCollision() throws {
        let home = try TestSupport.makeTempDir()
        let (renamer, _, space) = try makeRenamer(home: home)
        try fm.createDirectory(at: space.deletingLastPathComponent()
            .appendingPathComponent("Taken"), withIntermediateDirectories: true)

        XCTAssertThrowsError(try renamer.rename(space, to: "Taken", migrateMemory: false)) {
            XCTAssertEqual($0 as? WorkspaceError, .codingSpaceNameCollision("Taken"))
        }
        XCTAssertTrue(fm.fileExists(atPath: space.path), "冲突时原目录不动")
    }

    func testRenameRejectsEmptyOrSameName() throws {
        let home = try TestSupport.makeTempDir()
        let (renamer, _, space) = try makeRenamer(home: home)
        XCTAssertThrowsError(try renamer.rename(space, to: "  ", migrateMemory: false)) {
            XCTAssertEqual($0 as? WorkspaceError, .invalidCodingSpaceName)
        }
        XCTAssertThrowsError(try renamer.rename(space, to: "OldSpace", migrateMemory: false)) {
            XCTAssertEqual($0 as? WorkspaceError, .invalidCodingSpaceName)
        }
    }

    func testRenameMigratesAgentMemory() throws {
        let home = try TestSupport.makeTempDir()
        let (renamer, _, space) = try makeRenamer(home: home)
        let member = space.appendingPathComponent("member")
        try fm.createDirectory(at: member, withIntermediateDirectories: true)
        try makeClaudeMemory(home, projectPath: space.path)
        try makeClaudeMemory(home, projectPath: member.path, docs: ["m.md": "# m"])
        try makeCodexSession(home, id: "cs-1", cwd: member.path)

        let outcome = try renamer.rename(space, to: "NewSpace", migrateMemory: true)
        XCTAssertTrue(outcome.migrationFailures.isEmpty, "\(outcome.migrationFailures)")

        let reader = AgentMemoryReader(home: home)
        let newMember = outcome.newURL.appendingPathComponent("member")
        XCTAssertTrue(reader.snapshot(for: .claude, projectPath: outcome.newURL).available)
        XCTAssertEqual(reader.snapshot(for: .claude, projectPath: newMember).memoryDocs.count, 1)
        XCTAssertEqual(reader.snapshot(for: .codex, projectPath: newMember).sessions.count, 1)
    }

    func testRenameWithoutMigrationKeepsOldMemory() throws {
        let home = try TestSupport.makeTempDir()
        let (renamer, _, space) = try makeRenamer(home: home)
        try makeClaudeMemory(home, projectPath: space.path)

        let outcome = try renamer.rename(space, to: "NewSpace", migrateMemory: false)
        XCTAssertTrue(outcome.migrationResults.isEmpty)
        XCTAssertTrue(fm.fileExists(
            atPath: claudeProjectDir(home, for: space.path).appendingPathComponent("memory/a.md").path),
            "不转载则旧记忆原地不动")
    }

    func testPlanRenameReportsCounts() throws {
        let home = try TestSupport.makeTempDir()
        let (renamer, _, space) = try makeRenamer(home: home)
        try makeClaudeMemory(home, projectPath: space.path)
        try makeCodexSession(home, id: "cs-1", cwd: space.path)

        let plan = try renamer.planRename(of: space, to: "随便什么名")
        XCTAssertEqual(plan.claude.memoryDocs, 1)
        XCTAssertEqual(plan.claude.sessions, 1)
        XCTAssertEqual(plan.codex.sessions, 1)
        XCTAssertTrue(plan.hasAgentMemory)
        XCTAssertEqual(plan.newURL.lastPathComponent, "随便什么名")
    }

    // MARK: 空间记忆总览

    func testSpaceMemorySummaryCountsRootAndMembers() throws {
        let home = try TestSupport.makeTempDir()
        let sandbox = try TestSupport.makeTempDir()
        let space = sandbox.appendingPathComponent("space")
        let memberA = space.appendingPathComponent("memberA")
        let memberB = space.appendingPathComponent("memberB")
        for dir in [space, memberA, memberB] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try makeClaudeMemory(home, projectPath: memberA.path, docs: ["x.md": "# x"])
        try makeCodexSession(home, id: "cs-1", cwd: memberA.path)
        try makeCodexSession(home, id: "cs-2", cwd: memberB.path)

        let summary = AgentMemoryReader(home: home).spaceMemorySummary(in: space)
        XCTAssertEqual(summary.entries.count, 3)
        XCTAssertEqual(summary.root?.folderName, nil)
        XCTAssertEqual(summary.root?.claude.available, false)
        let a = summary.entries.first { $0.folderName == "memberA" }
        XCTAssertEqual(a?.claude.memoryDocs, 1)
        XCTAssertEqual(a?.codex.sessions, 1)
        let b = summary.entries.first { $0.folderName == "memberB" }
        XCTAssertEqual(b?.codex.sessions, 1)
        XCTAssertEqual(b?.claude.available, false)
    }
}
