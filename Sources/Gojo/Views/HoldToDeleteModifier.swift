import SwiftUI

struct HoldToDeleteModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    let enabled: Bool
    let trailingInset: CGFloat
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .allowsHitTesting(!isPresented)

            if isPresented {
                DeletionActionBar(
                    onDelete: confirmDelete,
                    onCancel: dismiss
                )
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .padding(.trailing, trailingInset)
                .transition(actionTransition)
                .zIndex(1)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            if isPresented {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.red.opacity(0.85), lineWidth: 2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .scaleEffect(isPresented && !reduceMotion ? 0.985 : 1)
        .onLongPressGesture(minimumDuration: 0.6) {
            guard enabled else { return }
            withAnimation(reduceMotion ? nil : Motion.dropZone) {
                isPresented = true
            }
        }
        .accessibilityAction(named: "显示删除操作") {
            guard enabled else { return }
            isPresented = true
        }
        .help(enabled ? "按住显示删除操作" : "")
        .onChange(of: enabled) { enabled in
            if !enabled {
                isPresented = false
            }
        }
    }

    private var actionTransition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .move(edge: .trailing)
                .combined(with: .scale(scale: 0.92, anchor: .trailing))
                .combined(with: .opacity)
        }
    }

    private func confirmDelete() {
        dismiss()
        onDelete()
    }

    private func dismiss() {
        withAnimation(reduceMotion ? nil : Motion.dropZone) {
            isPresented = false
        }
    }
}

extension View {
    func holdToDelete(enabled: Bool = true, trailingInset: CGFloat = 8,
                      onDelete: @escaping () -> Void) -> some View {
        modifier(HoldToDeleteModifier(
            enabled: enabled,
            trailingInset: trailingInset,
            onDelete: onDelete
        ))
    }
}
