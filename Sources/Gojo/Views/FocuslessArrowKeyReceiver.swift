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
        private var localMonitor: Any?

        init(onMove: @escaping (Int) -> Void) {
            self.onMove = onMove
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
                guard let self, let window,
                      let delta = CarouselKeyboardNavigation.delta(forKeyCode: event.keyCode),
                      CarouselKeyboardNavigation.shouldHandleArrowKey(
                          forKeyCode: event.keyCode,
                          isEventInReceiverWindow: event.window === window,
                          isReceiverWindowKey: NSApp.keyWindow === window,
                          isApplicationActive: NSApp.isActive,
                          hasAttachedSheet: window.attachedSheet != nil,
                          hasModalWindow: NSApp.modalWindow != nil,
                          isTextEditing: isTextEditing(window.firstResponder)
                      ) else {
                    return event
                }
                self.onMove(delta)
                return nil
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
