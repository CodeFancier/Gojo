import AppKit
import GojoCore

/// Decides whether an AppKit key event is consumed by carousel navigation.
final class CarouselKeyEventMonitor {
    var onMove: (Int) -> Void

    init(onMove: @escaping (Int) -> Void) {
        self.onMove = onMove
    }

    /// Returns nil only for an allowed mapped arrow key; otherwise returns the original event unchanged.
    func handle(_ event: NSEvent, isAllowed: Bool) -> NSEvent? {
        guard isAllowed, let delta = CarouselKeyboardNavigation.delta(forKeyCode: event.keyCode) else {
            return event
        }
        onMove(delta)
        return nil
    }
}
