public enum CarouselKeyboardNavigation {
    public static func delta(forKeyCode keyCode: UInt16) -> Int? {
        switch keyCode {
        case 123: -1
        case 124: 1
        default: nil
        }
    }

    public static func shouldHandleArrowKey(
        forKeyCode keyCode: UInt16,
        isEventInReceiverWindow: Bool,
        isReceiverWindowKey: Bool,
        isApplicationActive: Bool,
        hasAttachedSheet: Bool,
        hasModalWindow: Bool,
        isTextEditing: Bool
    ) -> Bool {
        delta(forKeyCode: keyCode) != nil
            && isEventInReceiverWindow
            && isReceiverWindowKey
            && isApplicationActive
            && !hasAttachedSheet
            && !hasModalWindow
            && !isTextEditing
    }
}
