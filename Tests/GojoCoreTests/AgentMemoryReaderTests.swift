import XCTest
@testable import GojoCore

final class AgentMemoryReaderTests: XCTestCase {

    // MARK: 路径编码

    func testClaudeDirNameReplacesNonAlnum() {
        XCTAssertEqual(
            AgentMemoryReader.claudeProjectDirName(for: "/Users/dev/Projects/Gojo"),
            "-Users-dev-Projects-Gojo")
    }

    func testClaudeDirNameDotsBecomeDash() {
        // 隐藏目录里的点号也转 `-`（连续分隔产生连续 `-`）。
        XCTAssertEqual(
            AgentMemoryReader.claudeProjectDirName(for: "/Users/x/.cc-switch/skills"),
            "-Users-x--cc-switch-skills")
    }

    // MARK: Claude 快照

    func testClaudeSnapshotReadsMemoryAndSessions() throws {
        let home = try TestSupport.makeTempDir()
        let project = URL(fileURLWithPath: "/Users/demo/proj")
        let enc = AgentMemoryReader.claudeProjectDirName(for: project.path)
        let dir = home.appendingPathComponent(".claude/projects/\(enc)", isDirectory: true)
        let memory = dir.appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memory, withIntermediateDirectories: true)

        try "# index".write(to: memory.appendingPathComponent("MEMORY.md"),
                            atomically: true, encoding: .utf8)
        try "# note".write(to: memory.appendingPathComponent("aaa.md"),
                           atomically: true, encoding: .utf8)

        // 一条会话：含 ai-title。
        let session = """
        {"type":"user","message":{"role":"user","content":"hi"}}
        {"type":"ai-title","aiTitle":"我的标题","sessionId":"sid-1"}
        """
        try session.write(to: dir.appendingPathComponent("sid-1.jsonl"),
                          atomically: true, encoding: .utf8)

        let snap = AgentMemoryReader(home: home).snapshot(for: .claude, projectPath: project)
        XCTAssertTrue(snap.available)
        XCTAssertEqual(snap.memoryDocs.first?.name, "MEMORY.md") // 置顶
        XCTAssertEqual(snap.memoryDocs.count, 2)
        XCTAssertEqual(snap.sessions.count, 1)
        XCTAssertEqual(snap.sessions.first?.id, "sid-1")
        XCTAssertEqual(snap.sessions.first?.title, "我的标题")
    }

    func testClaudeSnapshotResolvesSymlinkedProject() throws {
        let home = try TestSupport.makeTempDir()
        let fm = FileManager.default

        // 真实项目目录 + 指向它的软链接（模拟 symlink 成员）。
        let real = try TestSupport.makeTempDir().appendingPathComponent("realproj")
        try fm.createDirectory(at: real, withIntermediateDirectories: true)
        let link = try TestSupport.makeTempDir().appendingPathComponent("linkproj")
        try fm.createSymbolicLink(at: link, withDestinationURL: real)

        // Claude 目录按真实路径编码。
        let enc = AgentMemoryReader.claudeProjectDirName(for: real.resolvingSymlinksInPath().path)
        let dir = home.appendingPathComponent(".claude/projects/\(enc)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "{\"type\":\"ai-title\",\"aiTitle\":\"链接命中\",\"sessionId\":\"s\"}"
            .write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)

        // 用软链接路径查询，应解析到真实路径的 Claude 目录。
        let snap = AgentMemoryReader(home: home).snapshot(for: .claude, projectPath: link)
        XCTAssertTrue(snap.available)
        XCTAssertEqual(snap.sessions.first?.title, "链接命中")
    }

    func testClaudeSnapshotUnavailableWhenNoDir() throws {
        let home = try TestSupport.makeTempDir()
        let snap = AgentMemoryReader(home: home)
            .snapshot(for: .claude, projectPath: URL(fileURLWithPath: "/nope/here"))
        XCTAssertFalse(snap.available)
        XCTAssertTrue(snap.sessions.isEmpty)
    }

    // MARK: Codex 快照

    func testCodexSnapshotFiltersByCwdAndSkipsAgentsPreamble() throws {
        let home = try TestSupport.makeTempDir()
        let project = URL(fileURLWithPath: "/Users/demo/proj")
        let sessions = home.appendingPathComponent(".codex/sessions/2026/07/30", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)

        // 命中：cwd 匹配，首条 user 是注入的 AGENTS.md 应跳过，取第二条。
        let hit = """
        {"type":"session_meta","payload":{"id":"cs-1","cwd":"/Users/demo/proj"}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"# AGENTS.md instructions"}]}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"真正的问题"}]}}
        """
        try hit.write(to: sessions.appendingPathComponent("hit.jsonl"),
                      atomically: true, encoding: .utf8)

        // 不命中：cwd 是别的项目。
        let miss = """
        {"type":"session_meta","payload":{"id":"cs-2","cwd":"/Users/demo/other"}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"x"}]}}
        """
        try miss.write(to: sessions.appendingPathComponent("miss.jsonl"),
                       atomically: true, encoding: .utf8)

        let snap = AgentMemoryReader(home: home).snapshot(for: .codex, projectPath: project)
        XCTAssertTrue(snap.available)
        XCTAssertEqual(snap.sessions.count, 1)
        XCTAssertEqual(snap.sessions.first?.id, "cs-1")
        XCTAssertEqual(snap.sessions.first?.title, "真正的问题")
    }
}
