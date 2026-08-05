import GojoCore

struct CodingSpaceDeletionTask: Identifiable {
    let item: CodingSpaceRemovalItem
    var status: CodingSpaceDeletionTaskStatus = .pending

    var id: String { item.id }

    init(item: CodingSpaceRemovalItem) {
        self.item = item
    }
}
