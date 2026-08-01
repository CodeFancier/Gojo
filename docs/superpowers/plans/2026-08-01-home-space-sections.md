# Home Space Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the Gojo home screen into a cold-gray public-space status band above a brand-blue coding-space carousel.

**Architecture:** Keep `ShelfView` as the home-page composition layer and extract the two rows into focused SwiftUI views. `PublicSpaceSummary` derives display-only counts from existing `PublicProject` values; `CodingSpaceCarousel` owns the existing focus, scrolling, keyboard, and entry behavior. No `AppState` or `GojoCore` data-model changes are required.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 13+, Swift Package Manager, XCTest.

## Global Constraints

- Preserve the minimum window size of `720 × 460`.
- Use only the existing `chrome`, `surface`, `cardStroke`, `coreBlue`, `lightBlue`, and semantic text colors.
- Keep public-space navigation, coding-space navigation, space creation, Reduce Motion, keyboard navigation, and error handling behavior unchanged.
- Do not add dependencies, storage changes, sorting, search, or domain-page changes.
- Do not overwrite unrelated working-tree changes already present in the touched files.

---

### Task 1: Narrow the shelf item and card model to coding spaces

**Files:**
- Create: `Sources/Gojo/Views/ShelfItem.swift`
- Modify: `Sources/Gojo/Views/ShelfCard.swift`

**Interfaces:**
- Produces: `enum ShelfItem: Hashable { case coding(URL); case newSpace }`.
- Produces: `ShelfCard(item:focused:members:reduceMotion:)` for coding and creation cards only.

- [ ] **Step 1: Run the existing regression suite before changing the view model**

Run: `swift test`

Expected: all existing tests pass. There is no new unit test for the enum because it is executable-target-only UI composition with no new logic.

- [ ] **Step 2: Move and narrow `ShelfItem`**

Create `Sources/Gojo/Views/ShelfItem.swift`:

```swift
import Foundation

/// 首页编码空间轮播的一项。
enum ShelfItem: Hashable {
    case coding(URL)
    case newSpace
}
```

Delete the existing `ShelfItem` declaration from `ShelfCard.swift`.

- [ ] **Step 3: Remove public-space branches from `ShelfCard`**

Make `title` exhaustive for only `.coding` and `.newSpace`:

```swift
private var title: String {
    switch item {
    case .coding(let url): return url.lastPathComponent
    case .newSpace: return "新建编码空间"
    }
}
```

Rename the space-card comment to “编码空间卡” and use a fixed coding icon:

```swift
Label {
    Text(title)
        .font(.headline)
        .foregroundStyle(Color.textPrimary)
        .lineLimit(1)
} icon: {
    Image(systemName: "shippingbox.fill")
        .foregroundStyle(Color.textSecondary)
}
```

Replace the current `subtitle` switch with the coding-only count:

```swift
Text("\(members.count) 个仓库")
    .font(.subheadline)
    .foregroundStyle(Color.textTertiary)
```

- [ ] **Step 4: Compile the narrowed enum and card**

Run: `swift build`

Expected: compilation fails only where `ShelfView` still references `.publicSpace`; this proves the remaining integration point is explicit before Task 3. Record the compiler location, then continue.

- [ ] **Step 5: Commit the self-contained model/card change after Task 3 restores a green build**

Do not commit a knowingly non-compiling intermediate state. Include these files in the Task 3 implementation commit.

---

### Task 2: Add the public-space status band

**Files:**
- Create: `Sources/Gojo/Views/PublicSpaceSummary.swift`

**Interfaces:**
- Consumes: `isConfigured: Bool`, `projects: [PublicProject]`, `onOpen: () -> Void`.
- Produces: `PublicSpaceSummary`, a full-width `Button` with derived counts and a combined VoiceOver label.

- [ ] **Step 1: Implement derived presentation state without storage**

Create `Sources/Gojo/Views/PublicSpaceSummary.swift` with private computed properties:

```swift
import SwiftUI
import GojoCore

struct PublicSpaceSummary: View {
    let isConfigured: Bool
    let projects: [PublicProject]
    let onOpen: () -> Void

    private var clonedCount: Int { projects.lazy.filter(\.cloned).count }
    private var pendingCount: Int { projects.count - clonedCount }

    private var statusText: String {
        guard isConfigured else { return "尚未指定公共空间" }
        guard !projects.isEmpty else { return "暂无公共项目" }
        return "\(projects.count) 个公共项目"
    }

    private var detailText: String {
        guard isConfigured else { return "进入后选择公共文件夹" }
        guard !projects.isEmpty else { return "进入后添加共享项目" }
        return "\(clonedCount) 已克隆 · \(pendingCount) 待同步"
    }
```

- [ ] **Step 2: Build the cold-gray, fully tappable status band**

Use a semantic `Button`, not `onTapGesture`, and keep the label structurally distinct from the blue carousel:

```swift
Button(action: onOpen) {
    HStack(spacing: 14) {
        Label("公共空间", systemImage: "globe")
            .font(.headline)
            .foregroundStyle(Color.textPrimary)

        Divider()

        VStack(alignment: .leading, spacing: 3) {
            Text(statusText).font(.subheadline)
            Text(detailText)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }

        Spacer(minLength: 12)

        Label("打开公共空间", systemImage: "chevron.right")
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .contentShape(Rectangle())
}
.buttonStyle(.plain)
.background(Color.chrome, in: RoundedRectangle(cornerRadius: 14))
.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardStroke))
.accessibilityElement(children: .ignore)
.accessibilityLabel("公共空间，\(statusText)，\(detailText)")
.accessibilityHint("打开公共空间")
```

- [ ] **Step 3: Check the isolated view compiles**

Run: `swift build`

Expected: the only remaining compiler errors are the deliberate `.publicSpace` references in the old `ShelfView` queue and switch.

---

### Task 3: Compose the double-row home screen and restore all behavior

**Files:**
- Create: `Sources/Gojo/Views/CodingSpaceCarousel.swift`
- Modify: `Sources/Gojo/Views/ShelfView.swift`
- Modify: `Sources/Gojo/Views/ShelfCard.swift`
- Create: `Sources/Gojo/Views/ShelfItem.swift`

**Interfaces:**
- Consumes: `AppState.codingSpaces`, `AppState.members(in:)`, `AppState.createCodingSpace()`, and `AppState.route`.
- Produces: `CodingSpaceCarousel`, which owns coding-card focus and keyboard navigation.
- Produces: `ShelfView`, which composes `PublicSpaceSummary` and `CodingSpaceCarousel`.

- [ ] **Step 1: Move the existing carousel implementation into `CodingSpaceCarousel`**

Move `CardCenterKey`, `focusIndex`, `scrollLock`, `scrollGen`, scroll reporting, dots, `step`, `centerCard`, and coding-space entry logic from `ShelfView.swift` into `Sources/Gojo/Views/CodingSpaceCarousel.swift`.

Use only coding items:

```swift
private var items: [ShelfItem] {
    state.codingSpaces.map(ShelfItem.coding) + [.newSpace]
}
```

The entry switch becomes:

```swift
private func enter(_ item: ShelfItem) {
    switch item {
    case .coding(let url):
        withAnimation(reduceMotion ? nil : Motion.domain) {
            state.route = .codingSpace(url)
        }
    case .newSpace:
        state.createCodingSpace()
    }
}
```

Add a visible row heading above the carousel:

```swift
Label("编码空间", systemImage: "shippingbox.fill")
    .font(.headline)
    .foregroundStyle(Color.textPrimary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 42)
```

Keep the existing `ScrollViewReader`, `CarouselFocus`, click-to-center, second-click-to-enter, arrow-key handling, focus animation, dots, and Reduce Motion behavior unchanged.

- [ ] **Step 2: Reduce `ShelfView` to page composition**

Replace the old single-carousel body with:

```swift
var body: some View {
    VStack(spacing: 18) {
        PublicSpaceSummary(
            isConfigured: state.publicSpaceFolder != nil,
            projects: state.publicProjects,
            onOpen: openPublicSpace
        )
        .padding(.horizontal, 42)
        .padding(.top, 58)

        CodingSpaceCarousel()
    }
    .background(DomainBackground())
    .overlay(alignment: .topLeading) {
        BrandWordmark(height: 26)
            .padding(.leading, 84)
            .padding(.top, 14)
    }
    .overlay(alignment: .bottomTrailing) {
        AuthorCredit()
            .padding(.trailing, 16)
            .padding(.bottom, 12)
    }
}

private func openPublicSpace() {
    withAnimation(reduceMotion ? nil : Motion.domain) {
        state.route = .publicSpace
    }
}
```

Keep `@EnvironmentObject var state` and `@Environment(\.accessibilityReduceMotion)` in `ShelfView`.

- [ ] **Step 3: Build and fix only integration errors from the extraction**

Run: `swift build`

Expected: `Build complete!` with no errors. Do not broaden the change into unrelated existing SwiftUI cleanup.

- [ ] **Step 4: Run the full automated regression suite**

Run: `swift test`

Expected: all tests pass with zero failures.

- [ ] **Step 5: Perform the manual acceptance pass**

Run the app and verify at minimum size `720 × 460`:

1. The cold-gray public band sits above the blue coding carousel.
2. Unconfigured, empty, and populated public-space copy is correct.
3. The entire public band opens `.publicSpace` and VoiceOver announces the summary.
4. Coding cards still scroll, focus, enter on second click, respond to left/right keys, and create spaces.
5. The wordmark, dots, and author credit do not overlap either row.
6. Reduce Motion removes breathing and scrolling movement.

- [ ] **Step 6: Check the final diff and commit the UI change**

Run:

```bash
git diff --check
git diff -- Sources/Gojo/Views/ShelfView.swift \
  Sources/Gojo/Views/ShelfCard.swift \
  Sources/Gojo/Views/ShelfItem.swift \
  Sources/Gojo/Views/PublicSpaceSummary.swift \
  Sources/Gojo/Views/CodingSpaceCarousel.swift
```

Commit only the five files in scope:

```bash
git add Sources/Gojo/Views/ShelfView.swift \
  Sources/Gojo/Views/ShelfCard.swift \
  Sources/Gojo/Views/ShelfItem.swift \
  Sources/Gojo/Views/PublicSpaceSummary.swift \
  Sources/Gojo/Views/CodingSpaceCarousel.swift
git commit -m "feat: separate public and coding spaces on home"
```
