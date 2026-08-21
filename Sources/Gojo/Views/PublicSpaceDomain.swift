import SwiftUI
import GojoCore

/// 公共空间领域：未指定时显空态引导；已指定时列出项目（Clone / 已克隆）并可新增。
struct PublicSpaceDomain: View {
    @EnvironmentObject var state: AppState

    @State private var showAdd = false
    @State private var newName = ""
    @State private var newURL = ""
    @State private var query = ""
    @State private var sortOrder = PublicEntrySort.name

    var body: some View {
        VStack(spacing: 0) {
            DomainTopBar(title: "公共空间")
            if state.publicSpaceFolder == nil {
                emptyState
            } else {
                projectList
            }
        }
        .background(DomainBackground())
        .alert("新增公共项目", isPresented: $showAdd) {
            TextField("名称", text: $newName)
            TextField("Git URL", text: $newURL)
            Button("添加") {
                state.addPublicProject(name: newName, url: newURL)
                newName = ""; newURL = ""
            }
            Button("取消", role: .cancel) {}
        } message: { Text("只登记定义，点 Clone 才同步下来") }
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe").font(.system(size: 44)).foregroundStyle(Color.lightBlue)
            Text("还没有指定公共空间").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text("公共空间是所有共享仓库的家，指定一个文件夹开始")
                .font(.system(size: 12)).foregroundStyle(Color.textTertiary)
            Button("指定公共空间文件夹") { state.chooseAndSetPublicSpace() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 项目列表

    /// 名称或子仓库名命中即保留（命中子仓库时显示其父条目）。
    private var visibleEntries: [PublicSpaceEntry] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = keyword.isEmpty
            ? state.publicSpaceEntries
            : state.publicSpaceEntries.filter { entry in
                entry.name.localizedStandardContains(keyword)
                    || entry.projects.contains { $0.name.localizedStandardContains(keyword) }
            }
        return sortOrder.sorted(filtered)
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            if !state.publicSpaceEntries.isEmpty {
                filterBar
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if state.publicSpaceEntries.isEmpty {
                        Text("公共空间还是空的，点右下角 + 添加，或直接拖入仓库文件夹")
                            .font(.callout)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else if visibleEntries.isEmpty {
                        Text("没有匹配的条目")
                            .font(.callout)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    }
                    ForEach(visibleEntries) { entry in
                        PublicSpaceEntryRow(
                            entry: entry,
                            project: state.publicProjects.first { $0.id == entry.publicProjectID },
                            isBusy: isBusy(entry),
                            onClone: { state.clonePublicProject($0) },
                            onDelete: { state.removePublicProject($0) },
                            onPromote: { state.promotePublicProject(relativePath: $0) }
                        )
                    }
                }
                .padding(16)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent).clipShape(Circle())
            .padding(20)
        }
    }

    // MARK: 搜索与排序

    private var filterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                TextField("搜索名称或子仓库", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Color.chrome, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.publicStroke))
            .accessibilityLabel("搜索公共空间条目")

            Menu {
                Picker("排序方式", selection: $sortOrder) {
                    ForEach(PublicEntrySort.allCases) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text(sortOrder.label)
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Color.chrome, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.publicStroke))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("排序方式")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    private func isBusy(_ entry: PublicSpaceEntry) -> Bool {
        guard let space = state.publicSpaceFolder,
              let project = state.publicProjects.first(where: { $0.id == entry.publicProjectID })
        else { return false }
        return state.isBusy(space: space, folder: project.name)
    }
}

/// 公共空间列表的排序方式。纯展示逻辑，不进 GojoCore。
private enum PublicEntrySort: String, CaseIterable, Identifiable {
    case name
    case gitFirst
    case childCount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "名称"
        case .gitFirst: return "Git 优先"
        case .childCount: return "子仓库数"
        }
    }

    func sorted(_ entries: [PublicSpaceEntry]) -> [PublicSpaceEntry] {
        switch self {
        case .name:
            // API 已按 relativePath 名称序返回
            return entries
        case .gitFirst:
            return entries.sorted {
                (Self.gitRank($0), $0.relativePath)
                    < (Self.gitRank($1), $1.relativePath)
            }
        case .childCount:
            return entries.sorted {
                ($1.projects.count, $0.relativePath)
                    < ($0.projects.count, $1.relativePath)
            }
        }
    }

    /// Git 仓库（含未落盘的登记项）在前，普通文件夹在后。
    private static func gitRank(_ entry: PublicSpaceEntry) -> Int {
        (entry.isGitRepository || entry.publicProjectID != nil) ? 0 : 1
    }
}
