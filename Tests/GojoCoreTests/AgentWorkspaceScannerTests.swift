import XCTest
@testable import GojoCore

final class AgentWorkspaceScannerTests: XCTestCase {

    // MARK: Claude 反推

    func testScanDiscoversClaudeProjectFromCwd() throws {
        let home = try TestSupport.makeTempDir()
        let fm = FileManager.default
        let projectPath = "/Users/demo/app"
        let enc = AgentMemoryReader.claudeProjectDirName(for: projectPath)
        let dir = home.appendingPathComponent(".claude/projects/\(enc)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let session = """
        {"type":"user","cwd":"/Users/demo/app","message":{"role":"user","content":"hi"}}
        {"type":"assistant","cwd":"/Users/demo/app","message":{"role":"assistant","content":"yo"}}
        """
        try session.write(to: dir.appendingPathComponent("s1.jsonl"),
                          atomically: true, encoding: .utf8)
        try session.write(to: dir.appendingPathComponent("s2.jsonl"),
                          atomically: true, encoding: .utf8)

        let results = AgentWorkspaceScanner(home: home).scan()
        let app = try XCTUnwrap(results.first { $0.path.path == "/Users/demo/app" })
        XCTAssertTrue(app.kinds.contains(.claude))
        XCTAssertEqual(app.sessionCount, 2)      // 两个 jsonl 文件
        XCTAssertFalse(app.exists)               // /Users/demo/app 实际不存在
    }

    // MARK: Codex 反推

    func testScanDiscoversCodexProjectFromSessionMeta() throws {
        let home = try TestSupport.makeTempDir()
        let fm = FileManager.default
        let sessions = home.appendingPathComponent(".codex/sessions/2026/08/07", isDirectory: true)
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        let hit = """
        {"type":"session_meta","payload":{"id":"cs-1","cwd":"/Users/demo/lib"}}
        """
        try hit.write(to: sessions.appendingPathComponent("hit.jsonl"),
                      atomically: true, encoding: .utf8)

        let results = AgentWorkspaceScanner(home: home).scan()
        let lib = try XCTUnwrap(results.first { $0.path.path == "/Users/demo/lib" })
        XCTAssertTrue(lib.kinds.contains(.codex))
        XCTAssertEqual(lib.sessionCount, 1)
        XCTAssertFalse(lib.exists)
    }

    // MARK: 合并

    func testScanMergesClaudeAndCodexForSamePath() throws {
        let home = try TestSupport.makeTempDir()
        let fm = FileManager.default
        let projectPath = "/Users/demo/shared"

        let enc = AgentMemoryReader.claudeProjectDirName(for: projectPath)
        let cdir = home.appendingPathComponent(".claude/projects/\(enc)", isDirectory: true)
        try fm.createDirectory(at: cdir, withIntermediateDirectories: true)
        try "{\"type\":\"user\",\"cwd\":\"\(projectPath)\",\"message\":{\"role\":\"user\",\"content\":\"hi\"}}"
            .write(to: cdir.appendingPathComponent("a.jsonl"), atomically: true, encoding: .utf8)

        let sessions = home.appendingPathComponent(".codex/sessions/2026/08/07", isDirectory: true)
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        try "{\"type\":\"session_meta\",\"payload\":{\"id\":\"cs-1\",\"cwd\":\"\(projectPath)\"}}"
            .write(to: sessions.appendingPathComponent("b.jsonl"), atomically: true, encoding: .utf8)

        let results = AgentWorkspaceScanner(home: home).scan()
        let shared = try XCTUnwrap(results.first { $0.path.path == projectPath })
        XCTAssertEqual(shared.kinds, [.claude, .codex])
        XCTAssertEqual(shared.sessionCount, 2)   // Claude 1 + Codex 1
    }

    // MARK: exists

    func testScanMarksExistingProject() throws {
        let home = try TestSupport.makeTempDir()
        let fm = FileManager.default
        let real = home.appendingPathComponent("realproj")
        try fm.createDirectory(at: real, withIntermediateDirectories: true)

        let enc = AgentMemoryReader.claudeProjectDirName(for: real.path)
        let dir = home.appendingPathComponent(".claude/projects/\(enc)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "{\"type\":\"user\",\"cwd\":\"\(real.path)\",\"message\":{\"role\":\"user\",\"content\":\"hi\"}}"
            .write(to: dir.appendingPathComponent("a.jsonl"), atomically: true, encoding: .utf8)

        let results = AgentWorkspaceScanner(home: home).scan()
        let proj = try XCTUnwrap(results.first { $0.path.path == real.path })
        XCTAssertTrue(proj.exists)
    }

    // MARK: 空状态

    func testScanEmptyWhenNoSessions() throws {
        let home = try TestSupport.makeTempDir()
        XCTAssertTrue(AgentWorkspaceScanner(home: home).scan().isEmpty)
    }
}
