# Home Responsive Carousel and Persistent Public Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a fluid deep-blue coding-space carousel above a persistent, enlarged teal public-space bar that remains available and searchable inside coding-space details.

**Architecture:** Add two tested `GojoCore` helpers for public-project filtering and responsive card metrics. Move the public-space UI to a shared `PersistentPublicSpaceBar` hosted by `ContentView`, while `CodingSpaceDomain` receives the shared drag-session binding. Keep the existing carousel interaction but drive `ShelfCard` dimensions from viewport-derived metrics.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 13+, Swift Package Manager, XCTest.

## Global Constraints

- Keep the UI term “编码空间”; do not rename it to “开发空间”.
- Keep the minimum content size `720 × 460pt` usable without overlap.
- Use a deep-sea blue coding-space treatment and a teal public-space treatment; define new colors centrally in `Motion.swift`, never as scattered view-local RGB values.
- Preserve two-step carousel activation, arrow-key navigation, public-project drag payloads, Git/symlink drop zones, global error handling, Dynamic Type, VoiceOver, and Reduce Motion.
- Public-project search is local, case-insensitive, trims surrounding whitespace, matches name or Git URL, preserves source order, and never mutates `AppState.publicProjects`.
- The public bar is summary-only on `.shelf`, searchable/draggable on `.codingSpace` and `.shelfDropping`, and hidden on `.publicSpace`.
- Do not add dependencies, remote search, sorting, tags, favorites, storage changes, or public-space detail changes.
- Preserve all unrelated working-tree changes; stage and commit only files named by the current task.

---

### Task 1: Add tested public-project search

**Files:**
- Create: `Sources/GojoCore/Models/PublicProjectSearch.swift`
- Create: `Tests/GojoCoreTests/PublicProjectSearchTests.swift`

**Interfaces:**
- Consumes: `[PublicProject]` and a `String` query.
- Produces: `PublicProjectSearch.filter(_:query:) -> [PublicProject]`.

- [ ] **Step 1: Write failing tests for the complete search contract**

Create `Tests/GojoCoreTests/PublicProjectSearchTests.swift`:

```swift
import XCTest
@testable import GojoCore

final class PublicProjectSearchTests: XCTestCase {
    private let projects = [
        PublicProject(name: "SharedUI", url: "https://git.example.com/design/shared-ui.git"),
        PublicProject(name: "API Kit", url: "ssh://git.example.com/platform/api-kit.git"),
        PublicProject(name: "Docs", url: "https://code.example.com/handbook.git"),
    ]

    func testEmptyAndWhitespaceQueriesPreserveAllProjectsInOrder() {
        XCTAssertEqual(PublicProjectSearch.filter(projects, query: ""), projects)
        XCTAssertEqual(PublicProjectSearch.filter(projects, query: "   "), projects)
    }

    func testNameMatchIsCaseInsensitiveAndTrimmed() {
        XCTAssertEqual(
            PublicProjectSearch.filter(projects, query: "  SHAREDui ").map(\.name),
            ["SharedUI"]
        )
    }

    func testURLMatchIsCaseInsensitive() {
        XCTAssertEqual(
            PublicProjectSearch.filter(projects, query: "PLATFORM/API-KIT").map(\.name),
            ["API Kit"]
        )
    }

    func testNoMatchReturnsEmptyArray() {
        XCTAssertTrue(PublicProjectSearch.filter(projects, query: "missing").isEmpty)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter PublicProjectSearchTests`

Expected: compilation fails because `PublicProjectSearch` does not exist.

- [ ] **Step 3: Implement the minimal pure filter**

Create `Sources/GojoCore/Models/PublicProjectSearch.swift`:

```swift
import Foundation

public enum PublicProjectSearch {
    public static func filter(_ projects: [PublicProject], query: String) -> [PublicProject] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || $0.url.localizedCaseInsensitiveContains(needle)
        }
    }
}
```

- [ ] **Step 4: Run focused and full tests and verify GREEN**

Run: `swift test --filter PublicProjectSearchTests`

Expected: 4 tests pass, 0 failures.

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 5: Commit Task 1**

```bash
git add Sources/GojoCore/Models/PublicProjectSearch.swift \
  Tests/GojoCoreTests/PublicProjectSearchTests.swift
git commit -m "feat: add public project search"
```

---

### Task 2: Add tested responsive carousel metrics

**Files:**
- Create: `Sources/GojoCore/Models/CarouselCardMetrics.swift`
- Create: `Tests/GojoCoreTests/CarouselCardMetricsTests.swift`

**Interfaces:**
- Consumes: `viewportWidth: CGFloat`, `availableHeight: CGFloat`.
- Produces: `CarouselCardMetrics.calculate(viewportWidth:availableHeight:)` with `focusedSize`, `sideSize`, `horizontalInset`, and `spacing`.

- [ ] **Step 1: Write failing boundary and scaling tests**

Create `Tests/GojoCoreTests/CarouselCardMetricsTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import GojoCore

final class CarouselCardMetricsTests: XCTestCase {
    func testMinimumViewportClampsFocusedCardAndCentersIt() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 400, availableHeight: 180)
        XCTAssertEqual(metrics.focusedSize.width, 240, accuracy: 0.001)
        XCTAssertEqual(metrics.focusedSize.height, 180, accuracy: 0.001)
        XCTAssertEqual(metrics.horizontalInset, 80, accuracy: 0.001)
    }

    func testNormalViewportScalesFluidly() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 800, availableHeight: 250)
        XCTAssertEqual(metrics.focusedSize.width, 288, accuracy: 0.001)
        XCTAssertEqual(metrics.focusedSize.height, 206, accuracy: 0.001)
        XCTAssertEqual(metrics.sideSize.width, 184.32, accuracy: 0.001)
        XCTAssertEqual(metrics.sideSize.height, 156.56, accuracy: 0.001)
    }

    func testWideViewportClampsMaximums() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 2_000, availableHeight: 500)
        XCTAssertEqual(metrics.focusedSize.width, 360, accuracy: 0.001)
        XCTAssertEqual(metrics.focusedSize.height, 250, accuracy: 0.001)
        XCTAssertEqual(metrics.horizontalInset, 820, accuracy: 0.001)
        XCTAssertEqual(metrics.spacing, 22, accuracy: 0.001)
    }

    func testSideCardMinimumsRemainReadable() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 400, availableHeight: 180)
        XCTAssertEqual(metrics.sideSize.width, 153.6, accuracy: 0.001)
        XCTAssertEqual(metrics.sideSize.height, 140, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(metrics.horizontalInset, 0)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter CarouselCardMetricsTests`

Expected: compilation fails because `CarouselCardMetrics` does not exist.

- [ ] **Step 3: Implement the exact calculation contract**

Create `Sources/GojoCore/Models/CarouselCardMetrics.swift`:

```swift
import CoreGraphics

public struct CarouselCardMetrics: Equatable, Sendable {
    public let focusedSize: CGSize
    public let sideSize: CGSize
    public let horizontalInset: CGFloat
    public let spacing: CGFloat

    public static func calculate(
        viewportWidth: CGFloat,
        availableHeight: CGFloat
    ) -> CarouselCardMetrics {
        let safeWidth = max(0, viewportWidth)
        let safeHeight = max(0, availableHeight)
        let focusedWidth = min(360, max(240, safeWidth * 0.36))
        let focusedHeight = min(250, max(180, safeHeight - 44))
        let sideWidth = max(150, focusedWidth * 0.64)
        let sideHeight = max(140, focusedHeight * 0.76)
        return CarouselCardMetrics(
            focusedSize: CGSize(width: focusedWidth, height: focusedHeight),
            sideSize: CGSize(width: sideWidth, height: sideHeight),
            horizontalInset: max(0, (safeWidth - focusedWidth) / 2),
            spacing: min(22, max(12, safeWidth * 0.018))
        )
    }
}
```

- [ ] **Step 4: Run focused and full tests and verify GREEN**

Run: `swift test --filter CarouselCardMetricsTests`

Expected: 4 tests pass, 0 failures.

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 5: Commit Task 2**

```bash
git add Sources/GojoCore/Models/CarouselCardMetrics.swift \
  Tests/GojoCoreTests/CarouselCardMetricsTests.swift
git commit -m "feat: add responsive carousel metrics"
```

---

### Task 3: Replace separate public summaries and trays with one persistent bar

**Files:**
- Create: `Sources/Gojo/Views/PublicSpaceBarMode.swift`
- Create: `Sources/Gojo/Views/PersistentPublicSpaceBar.swift`
- Modify: `Sources/Gojo/Views/ContentView.swift`
- Modify: `Sources/Gojo/Views/ShelfView.swift`
- Modify: `Sources/Gojo/Views/CodingSpaceDomain.swift`
- Modify: `Sources/Gojo/Views/Motion.swift`
- Delete: `Sources/Gojo/Views/PublicSpaceSummary.swift`
- Delete: `Sources/Gojo/Views/ProjectTray.swift`

**Interfaces:**
- Consumes: `PublicProjectSearch.filter(_:query:)` from Task 1.
- Produces: `PublicSpaceBarMode { summary, searchable }`.
- Produces: `PersistentPublicSpaceBar(mode:onOpen:onDragProject:)`.
- Produces: `CodingSpaceDomain(space:draggingProjectId:)` where `draggingProjectId` is `Binding<UUID?>`.

- [ ] **Step 1: Add the bar mode and centralized teal colors**

Create `Sources/Gojo/Views/PublicSpaceBarMode.swift`:

```swift
enum PublicSpaceBarMode: Equatable {
    case summary
    case searchable
}
```

Add these semantic colors to `Motion.swift` beside the existing brand colors:

```swift
static let publicTeal = Color(red: 45/255, green: 212/255, blue: 191/255)
static let publicSurface = Color(red: 13/255, green: 148/255, blue: 136/255).opacity(0.22)
static let publicStroke = Color.publicTeal.opacity(0.42)
```

- [ ] **Step 2: Build the reusable persistent bar**

Create `Sources/Gojo/Views/PersistentPublicSpaceBar.swift` with:

```swift
import SwiftUI
import GojoCore

struct PersistentPublicSpaceBar: View {
    @EnvironmentObject private var state: AppState
    @State private var query = ""

    let mode: PublicSpaceBarMode
    let onOpen: () -> Void
    let onDragProject: (UUID) -> Void

    private var visibleProjects: [PublicProject] {
        PublicProjectSearch.filter(state.publicProjects, query: query)
    }

    private var clonedCount: Int { state.publicProjects.lazy.filter(\.cloned).count }
    private var pendingCount: Int { state.publicProjects.count - clonedCount }
```

The summary mode must be one full-width plain `Button` using:

```swift
Label("公共空间", systemImage: "globe")
    .font(.title3.bold())
    .foregroundStyle(Color.publicTeal)
```

Show the main status with `.font(.body)` and supporting copy with `.font(.callout)`. Use `Color.publicSurface` as the background and `Color.publicStroke` as the border. Preserve the three summary states: unconfigured, configured-empty, and populated counts.

The searchable mode must show the same title and stats, then:

```swift
TextField("搜索公共项目", text: $query)
    .textFieldStyle(.plain)
    .font(.body)
    .padding(.horizontal, 12)
    .frame(minHeight: 34)
    .background(Color.chrome, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.publicStroke))
    .accessibilityLabel("搜索公共项目")
```

When configured with projects, render `visibleProjects` in a horizontal `ScrollView`. Each project card uses `SourceBadgeIcon(kind: .unjoinedPublic, size: 18)`, `.body` for the name, `.caption` for a one-line URL, minimum width `140`, and the existing `DragPayload.publicProject` inside `.onDrag`. Call `onDragProject(project.id)` before returning the provider.

Show exact empty copy:

- Unconfigured: `未指定公共空间，请先进入公共空间设置`
- Configured with no projects: `公共空间暂无项目`
- Non-empty source with empty filtered result: `没有匹配的公共项目`

Clear `query` when `mode` changes to `.summary` using `.onChange(of: mode)`.

- [ ] **Step 3: Host the bar below route content in `ContentView`**

Add shared drag state:

```swift
@State private var draggingPublicProjectId: UUID?
```

Replace the root route-only stack with a `VStack(spacing: 0)` containing the existing route content and the conditional bar. Derive mode without adding it to `AppState`:

```swift
private var publicBarMode: PublicSpaceBarMode? {
    switch state.route {
    case .shelf:
        return .summary
    case .codingSpace, .shelfDropping:
        return .searchable
    case .publicSpace:
        return nil
    }
}
```

Render:

```swift
if let mode = publicBarMode {
    PersistentPublicSpaceBar(
        mode: mode,
        onOpen: openPublicSpace,
        onDragProject: beginPublicProjectDrag
    )
    .transition(.opacity)
}
```

`openPublicSpace()` routes to `.publicSpace` with `Motion.domain` unless Reduce Motion is enabled. `beginPublicProjectDrag(_:)` only sets `draggingPublicProjectId` when the current route is `.codingSpace` or `.shelfDropping`, using `Motion.dropZone` unless Reduce Motion is enabled.

Pass `$draggingPublicProjectId` to both `CodingSpaceDomain` construction sites. Clear it when leaving a coding-space route with `.onChange(of: state.route)`.

- [ ] **Step 4: Move drag-session ownership out of `CodingSpaceDomain`**

Replace its local state:

```swift
@State private var draggingProjectId: UUID?
```

with:

```swift
@Binding var draggingProjectId: UUID?
```

Keep the existing opacity, `DropZones`, `addPublicToSpace`, dismissal, and Reduce Motion behavior. Remove the trailing `ProjectTray` from the domain `VStack`; the persistent bar now occupies that location in `ContentView`.

- [ ] **Step 5: Remove the old duplicate public-space views and simplify `ShelfView`**

Delete `PublicSpaceSummary.swift` and `ProjectTray.swift`.

Remove `PublicSpaceSummary`, `openPublicSpace`, and the public summary spacing from `ShelfView`. Its page content becomes only `CodingSpaceCarousel`, with the existing brand wordmark and author credit overlays. Keep the accessibility-size vertical-scroll fallback only if the carousel itself needs it after the persistent bar reduces available height.

- [ ] **Step 6: Build and run all tests**

Run: `swift build`

Expected: `Build complete!` with no stale `ProjectTray` or `PublicSpaceSummary` references.

Run: `swift test`

Expected: all tests, including Task 1 and Task 2 tests, pass.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 7: Commit Task 3**

```bash
git add Sources/Gojo/Views/PublicSpaceBarMode.swift \
  Sources/Gojo/Views/PersistentPublicSpaceBar.swift \
  Sources/Gojo/Views/ContentView.swift \
  Sources/Gojo/Views/ShelfView.swift \
  Sources/Gojo/Views/CodingSpaceDomain.swift \
  Sources/Gojo/Views/Motion.swift \
  Sources/Gojo/Views/PublicSpaceSummary.swift \
  Sources/Gojo/Views/ProjectTray.swift
git commit -m "feat: add persistent public space bar"
```

---

### Task 4: Apply fluid viewport sizing to the coding-space carousel

**Files:**
- Modify: `Sources/Gojo/Views/CodingSpaceCarousel.swift`
- Modify: `Sources/Gojo/Views/ShelfCard.swift`
- Modify: `Sources/Gojo/Views/ShelfView.swift`

**Interfaces:**
- Consumes: `CarouselCardMetrics.calculate(viewportWidth:availableHeight:)` from Task 2.
- Produces: `ShelfCard(item:focused:members:reduceMotion:focusedSize:sideSize:)`.

- [ ] **Step 1: Make `ShelfCard` consume explicit responsive sizes**

Add properties:

```swift
let focusedSize: CGSize
let sideSize: CGSize
```

Replace the fixed frame with:

```swift
let size = focused ? focusedSize : sideSize
// ... existing card content ...
.frame(width: size.width, height: size.height)
.opacity(focused ? 1 : 0.42)
.saturation(focused ? 1 : 0.5)
.offset(y: focused && breathe && !reduceMotion ? -4 : 0)
.animation(reduceMotion ? nil : Motion.domain, value: size)
```

Remove the old fixed `240/150` frame and redundant `scaleEffect`; the metrics already encode the side-card ratio. Keep all card content, AX labels supplied by the parent button, and the breathing guard.

- [ ] **Step 2: Calculate metrics from the actual carousel viewport**

Inside `CodingSpaceCarousel`’s existing `GeometryReader`, after reserving `26pt` for dots:

```swift
let metrics = CarouselCardMetrics.calculate(
    viewportWidth: geo.size.width,
    availableHeight: cardAreaHeight
)
```

Use `metrics.spacing` in the card `HStack`, pass both sizes to every `ShelfCard`, and replace fixed horizontal padding with `metrics.horizontalInset`.

The updated card helper signature is:

```swift
private func card(
    _ index: Int,
    _ item: ShelfItem,
    proxy: ScrollViewProxy,
    metrics: CarouselCardMetrics
) -> some View
```

Keep focus reporting, Button semantics, two-step activation, search-independent IDs, arrow keys, dots, and Reduce Motion unchanged.

- [ ] **Step 3: Give the carousel all remaining home-page height**

`ShelfView` should contain the carousel in a flexible frame:

```swift
CodingSpaceCarousel()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
```

Keep the top wordmark and bottom-trailing author credit clear of the title, carousel dots, and persistent bar. For accessibility Dynamic Type, use vertical scrolling only when content cannot fit; do not cap the user’s text size.

- [ ] **Step 4: Run automated verification**

Run: `swift build`

Expected: build succeeds.

Run: `swift test --filter CarouselCardMetricsTests`

Expected: 4 tests pass, 0 failures.

Run: `swift test --filter CarouselFocusTests`

Expected: the existing focus tests pass.

Run: `swift test`

Expected: all tests pass.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 5: Perform the real UI acceptance pass using the latest build**

Verify without terminating an unrelated user-run app; use a temporary unique bundle identifier if necessary:

1. At a `720 × 460pt` content area, the coding title, carousel, dots, enlarged public bar, wordmark, and author credit remain reachable without overlap.
2. Continuously resize from 720pt to at least 1200pt wide; focused width grows from its clamped/fluid value up to 360pt, side cards remain proportional, and first/last cards center correctly.
3. Activate a side card once to center and again to enter; verify left/right keys and new-space activation.
4. Confirm the public bar remains at the bottom while switching from shelf to coding space and changes from summary to searchable mode.
5. Search by mixed-case project name and by URL; verify whitespace trimming and the no-result copy.
6. Drag a filtered project into both enabled drop modes and cancel without leaving stale overlays.
7. Check AX roles/labels for the public summary button, search field, project cards, and carousel cards.
8. Verify accessibility-size layout and Reduce Motion behavior; if system settings cannot be changed safely, document the exact source evidence and size budget without claiming a hand test.

- [ ] **Step 6: Inspect and commit only Task 4 files**

Run:

```bash
git diff --check
git diff -- Sources/Gojo/Views/CodingSpaceCarousel.swift \
  Sources/Gojo/Views/ShelfCard.swift \
  Sources/Gojo/Views/ShelfView.swift
```

Commit:

```bash
git add Sources/Gojo/Views/CodingSpaceCarousel.swift \
  Sources/Gojo/Views/ShelfCard.swift \
  Sources/Gojo/Views/ShelfView.swift
git commit -m "feat: make coding carousel responsive"
```
