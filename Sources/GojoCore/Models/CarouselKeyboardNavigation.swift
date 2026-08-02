public enum CarouselKeyboardNavigation {
    public static func delta(forKeyCode keyCode: UInt16) -> Int? {
        switch keyCode {
        case 123: -1
        case 124: 1
        default: nil
        }
    }
}
