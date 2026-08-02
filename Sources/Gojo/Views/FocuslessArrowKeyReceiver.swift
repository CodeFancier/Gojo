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
        var onMove: (Int) -> Void {
            didSet {
                keyEventMonitor.onMove = onMove
            }
        }
        private let keyEventMonitor: CarouselKeyEventMonitor
        private var localMonitor: Any?

        init(onMove: @escaping (Int) -> Void) {
            self.onMove = onMove
            self.keyEventMonitor = CarouselKeyEventMonitor(onMove: onMove)
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            removeLocalMonitor()
        }

        override func isAccessibilityElement() -> Bool {
            false
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            removeLocalMonitor()
            super.viewWillMove(toWindow: newWindow)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            focusRingType = .none
            guard let window else { return }
            installLocalMonitor(for: window)
        }

        private func installLocalMonitor(for window: NSWindow) {
            guard localMonitor == nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
                guard let self, let window else {
                    return event
                }
                let isAllowed = CarouselKeyboardNavigation.shouldHandleArrowKey(
                    forKeyCode: event.keyCode,
                    isEventInReceiverWindow: event.window === window,
                    isReceiverWindowKey: NSApp.keyWindow === window,
                    isApplicationActive: NSApp.isActive,
                    hasAttachedSheet: window.attachedSheet != nil,
                    hasModalWindow: NSApp.modalWindow != nil,
                    isTextEditing: isTextEditing(window.firstResponder)
                )
                return self.keyEventMonitor.handle(event, isAllowed: isAllowed)
            }
        }

        private func removeLocalMonitor() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
        }

        private func isTextEditing(_ responder: NSResponder?) -> Bool {
            responder is NSTextView || responder is NSTextField
        }
    }
}
