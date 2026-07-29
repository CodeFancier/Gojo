import Foundation

public struct ShellResult {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
}

public struct ShellRunner {
    public init() {}

    /// 经 /usr/bin/env 调用工具，复用用户 PATH 与环境（含 git 凭据配置）。
    public func run(_ tool: String, _ args: [String], cwd: URL? = nil) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + args
        if let cwd { process.currentDirectoryURL = cwd }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ShellResult(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}
