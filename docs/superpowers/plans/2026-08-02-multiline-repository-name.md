# Multiline Repository Name Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show coding-space repository names across up to three natural text lines instead of truncating them to one line.

**Architecture:** Keep the existing adaptive `220...280pt` member grid and change only `MemberCard`'s repository-name presentation. Let the text accept vertical growth within its proposed card width, and use the native macOS help tooltip as a complete-name fallback for exceptionally long names.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 13+, Swift Package Manager.

## Global Constraints

- Keep member-card widths adaptive from `220pt` through `280pt`.
- Repository names wrap naturally for at most 3 visible lines and do not reserve unused line height for short names.
- The complete repository name is available from a native hover help tooltip.
- Preserve branch text, source icon, Agent Memory controls, hover action bar, context menu, drag behavior, VoiceOver, and Reduce Motion.
- Do not add dependencies or raise the macOS 13 deployment target.
- Preserve all unrelated dirty-worktree changes and stage only the task's exact `MemberCard.swift` hunk.

---

### Task 1: Show repository names on multiple lines

**Files:**
- Modify: `Sources/Gojo/Views/MemberCard.swift`

**Interfaces:**
- Consumes: the grid's existing `220...280pt` width proposal.
- Produces: a repository-name `Text` with up to three natural lines and full-name help text.

- [ ] **Step 1: Update the repository-name text layout**

Change only the repository-name modifier chain:

```swift
Text(member.folderName)
    .font(.system(size: 13, weight: .semibold))
    .foregroundStyle(.white)
    .lineLimit(3)
    .fixedSize(horizontal: false, vertical: true)
    .help(member.folderName)
```

Remove `.truncationMode(.middle)`. Do not reserve three lines with `reservesSpace`, because short names must keep their compact height.

- [ ] **Step 2: Align variable-height card headers from the top**

Change the card header from:

```swift
HStack(spacing: 10) {
```

to:

```swift
HStack(alignment: .top, spacing: 10) {
```

This keeps the source icon and Agent Memory controls aligned predictably when the central name/branch column becomes taller.

- [ ] **Step 3: Run automated verification**

Run: `swift build`

Expected: build succeeds.

Run: `swift test`

Expected: all tests pass.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 4: Verify the layout with deterministic names**

Use a temporary, non-committed test fixture or isolated app data containing:

```text
short-repo
payment-platform-cross-border-reconciliation-service
```

At a 720pt window, verify:

- the short name remains one line without blank reserved rows;
- the long name wraps to 2–3 lines without middle ellipsis;
- hovering the long name exposes its complete text;
- three columns remain horizontally unclipped;
- branch, memory controls, hover actions, context menu, and drag remain reachable.

Remove the temporary fixture after acceptance; do not commit user data.

- [ ] **Step 5: Stage only the repository-name hunk and commit**

Inspect both the full working-tree diff and staged diff. Use patch staging so the user's pre-existing Agent Memory and styling hunks remain unstaged:

```bash
git diff -- Sources/Gojo/Views/MemberCard.swift
git add -p Sources/Gojo/Views/MemberCard.swift
git diff --cached -- Sources/Gojo/Views/MemberCard.swift
git commit -m "fix: show multiline repository names"
```

- [ ] **Step 6: Prove the committed tree is isolated**

Export the new `HEAD` with `git archive` to a temporary directory and run `swift build` plus `swift test` there. Confirm the archive contains no untracked Agent Memory files and that the user's pre-existing hunks remain unstaged in the original working tree.
