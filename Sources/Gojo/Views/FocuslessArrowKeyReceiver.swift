import AppKit
import SwiftUI
import GojoCore

struct FocuslessArrowKeyReceiver: NSViewRepresentable {
    let onMove: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        ArrowKeyReceiverView(onMove: onMove)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ArrowKeyReceiverView)?.onMove = onMove
    }

    private final class ArrowKeyReceiverView: NSView {
        var onMove: (Int) -> Void

        init(onMove: @escaping (Int) -> Void) {
            self.onMove = onMove
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        override func isAccessibilityElement() -> Bool {
            false
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            focusRingType = .none
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            guard let delta = CarouselKeyboardNavigation.delta(forKeyCode: event.keyCode) else {
                super.keyDown(with: event)
                return
            }
            onMove(delta)
        }
    }
}
