import Foundation
import GojoCore

struct CodingSpaceDeletionSession: Identifiable {
    let id = UUID()
    let space: URL
    var tasks: [CodingSpaceDeletionTask]
    var phase: CodingSpaceDeletionPhase = .review

    var hasFailures: Bool {
        tasks.contains {
            if case .failed = $0.status { return true }
            return false
        }
    }
}
