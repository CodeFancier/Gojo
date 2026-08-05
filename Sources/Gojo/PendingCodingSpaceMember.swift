import Foundation
import GojoCore

struct PendingCodingSpaceMember: Identifiable, Equatable {
    let projectID: UUID
    let folderName: String
    let mode: MemberMode

    var id: String { folderName }
}
