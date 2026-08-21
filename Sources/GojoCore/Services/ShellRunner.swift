import Foundation

public struct ShellResult {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
}

public struct ShellRunner {
    public init() {}

    /// 读管道结果的持有盒：读线程写、group.wait() 之后主流程读，
    /// dispatch group 的完成边界保证了内存可见性，无需额外加锁。
    final class DataBox: @unchecked Sendable { var data = Data() }

    /// 经 /usr/bin/env 调用工具，复用用户 PATH 与环境（含 git 凭据配置）。
    /// environment 在当前环境之上追加/覆盖（而非整体替换），避免丢掉 HOME/PATH。
    public func run(_ tool: String, _ args: [String], cwd: URL? = nil,
                    environment: [String: String] = [:]) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + args
        if let cwd { process.currentDirectoryURL = cwd }
        if !environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (k, v) in environment { env[k] = v }
            process.environment = env
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        // stdout/stderr 必须并发读：git 的进度与错误全走 stderr 而 stdout 常为空，
        // 若先同步读 stdout 到 EOF，一旦 stderr 写满管道缓冲区（约 64KB），子进程
        // 阻塞在 write 上永不退出，父进程也永远等不到 stdout 的 EOF——互锁，
        // 表现为克隆永不结束、界面永远停在「克隆中」。
        let outBox = DataBox(), errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.wait()
        let outData = outBox.data
        let errData = errBox.data
        process.waitUntilExit()

        return ShellResult(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}
