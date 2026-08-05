enum CodingSpaceDeletionTaskStatus: Equatable {
    case pending
    case running
    case completed
    case failed(String)
}
