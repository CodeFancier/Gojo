# Focus Ring and Member Name Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the carousel's system blue focus rectangle without losing arrow-key navigation, and give coding-space project names more horizontal room.

**Architecture:** Introduce a small tested `GojoCore` key-code mapper and a macOS 13 AppKit-backed SwiftUI key receiver whose `NSView` accepts first responder status with `focusRingType = .none`. Replace the carousel's `.focusable()`/`.onMoveCommand` pair with that receiver. Let `MemberCard` fill wider adaptive grid columns rather than enforcing a fixed width.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, macOS 13+, Swift Package Manager, XCTest.

## Global Constraints

- Remove only the outer system blue focus rectangle; preserve the focused card's existing stroke, glow, dots, two-step activation, and VoiceOver semantics.
- Preserve left/right arrow navigation on macOS 13 and later.
- Do not add third-party dependencies or raise the deployment target.
- Coding-space member cards use adaptive widths from `220pt` through `280pt`.
- Project names remain one line and use middle truncation; branch, memory, hover actions, menus, and drag behavior remain unchanged.
- Preserve all unrelated dirty-worktree changes and commit only files named by each task.

---

### Task 1: Add focus-ring-free carousel keyboard navigation

**Files:**
- Create: `Sources/GojoCore/Models/CarouselKeyboardNavigation.swift`
- Create: `Tests/GojoCoreTests/CarouselKeyboardNavigationTests.swift`
- Create: `Sources/Gojo/Views/FocuslessArrowKeyReceiver.swift`
- Modify: `Sources/Gojo/Views/CodingSpaceCarousel.swift`

**Interfaces:**
- Produces: `CarouselKeyboardNavigation.delta(forKeyCode: UInt16) -> Int?`.
- Produces: `FocuslessArrowKeyReceiver(onMove: (Int) -> Void)`.
- Consumes: the carousel's existing `step(_:proxy:)` method.

- [ ] **Step 1: Write failing key-mapping tests**

Create `Tests/GojoCoreTests/CarouselKeyboardNavigationTests.swift`:

```swift
import XCTest
@testable import GojoCore

final class CarouselKeyboardNavigationTests: XCTestCase {
    func testLeftArrowMovesBackward() {
        XCTAssertEqual(CarouselKeyboardNavigation.delta(forKeyCode: 123), -1)
    }

    func testRightArrowMovesForward() {
        XCTAssertEqual(CarouselKeyboardNavigation.delta(forKeyCode: 124), 1)
    }

    func testOtherKeysPassThrough() {
        XCTAssertNil(CarouselKeyboardNavigation.delta(forKeyCode: 36))
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter CarouselKeyboardNavigationTests`

Expected: compilation fails because `CarouselKeyboardNavigation` does not exist.

- [ ] **Step 3: Implement the minimal key mapper**

Create `Sources/GojoCore/Models/CarouselKeyboardNavigation.swift`:

```swift
public enum CarouselKeyboardNavigation {
    public static func delta(forKeyCode keyCode: UInt16) -> Int? {
        switch keyCode {
        case 123: -1
        case 124: 1
        default: nil
        }
    }
}
```

- [ ] **Step 4: Implement the AppKit key receiver**

Create `Sources/Gojo/Views/FocuslessArrowKeyReceiver.swift` with an `NSViewRepresentable`. Its private `NSView` subclass must:

```swift
override var acceptsFirstResponder: Bool { true }

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
```

The representable updates the stored callback from `updateNSView`. It draws no content and exposes no accessibility element of its own.

- [ ] **Step 5: Replace the carousel focus modifier**

In `CodingSpaceCarousel`, remove `.focusable()` and `.onMoveCommand`. Add the receiver as a background of the `ScrollViewReader` content:

```swift
.background {
    FocuslessArrowKeyReceiver { delta in
        step(delta, proxy: proxy)
    }
}
```

Do not change `step`, card `Button` semantics, focus reporting, dots, or Reduce Motion.

- [ ] **Step 6: Verify focused and full tests**

Run: `swift test --filter CarouselKeyboardNavigationTests`

Expected: 3 tests pass, 0 failures.

Run: `swift test --filter CarouselFocusTests`

Expected: all existing focus tests pass.

Run: `swift build && swift test && git diff --check`

Expected: build succeeds, all tests pass, and no whitespace errors are reported.

- [ ] **Step 7: Perform keyboard UI acceptance**

Using the latest build, activate the shelf window and press left/right arrows. Confirm cards move and center, two-step activation still works, and no blue rectangle appears around the carousel. Confirm unhandled keys are not swallowed. Do not claim a hand test if the app window cannot be controlled reliably.

- [ ] **Step 8: Commit Task 1**

```bash
git add Sources/GojoCore/Models/CarouselKeyboardNavigation.swift \
  Tests/GojoCoreTests/CarouselKeyboardNavigationTests.swift \
  Sources/Gojo/Views/FocuslessArrowKeyReceiver.swift \
  Sources/Gojo/Views/CodingSpaceCarousel.swift
git commit -m "fix: remove carousel focus ring"
```

---

### Task 2: Widen coding-space member cards and project names

**Files:**
- Modify: `Sources/Gojo/Views/CodingSpaceDomain.swift`
- Modify: `Sources/Gojo/Views/MemberCard.swift`

**Interfaces:**
- Consumes: `LazyVGrid` adaptive column proposals.
- Produces: member-card widths in the inclusive `220...280pt` range.

- [ ] **Step 1: Widen the adaptive grid**

Change `CodingSpaceDomain.columns` to:

```swift
private let columns = [
    GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12, alignment: .top)
]
```

- [ ] **Step 2: Let member cards fill the grid cell**

In `MemberCard`, update the project-name text and outer frame:

```swift
Text(member.folderName)
    .font(.system(size: 13, weight: .semibold))
    .foregroundStyle(.white)
    .lineLimit(1)
    .truncationMode(.middle)

// Replace the fixed 168pt frame:
.frame(maxWidth: .infinity, alignment: .leading)
```

Keep the branch text, Agent Memory buttons, hover action bar, menus, drag payload, and accessibility behavior unchanged.

- [ ] **Step 3: Run automated verification**

Run: `swift build`

Expected: build succeeds.

Run: `swift test`

Expected: all tests pass.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 4: Perform layout UI acceptance**

At 720pt width, enter a coding space and confirm three readable columns without horizontal clipping. Resize wider and confirm the cards remain within `220...280pt`. Check a deliberately long project name retains both its beginning and ending with middle truncation. Verify hover actions, branch label, memory buttons, context menu, and drag still work.

- [ ] **Step 5: Commit Task 2**

```bash
git add Sources/Gojo/Views/CodingSpaceDomain.swift \
  Sources/Gojo/Views/MemberCard.swift
git commit -m "feat: widen coding project cards"
```
