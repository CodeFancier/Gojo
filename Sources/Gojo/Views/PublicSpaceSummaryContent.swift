import SwiftUI

struct PublicSpaceSummaryContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let statusText: String
    let detailText: String

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) {
                Label("公共空间", systemImage: "globe")
                    .font(.title3.bold())
                    .foregroundStyle(Color.publicTeal)
                Text(statusText)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                Text(detailText)
                    .font(.callout)
                    .foregroundStyle(Color.textTertiary)
                Label("打开公共空间", systemImage: "chevron.right")
                    .font(.callout.bold())
                    .foregroundStyle(Color.publicTeal)
            }
        } else {
            HStack(spacing: 28) {
                Label("公共空间", systemImage: "globe")
                    .font(.title3.bold())
                    .foregroundStyle(Color.publicTeal)
                    .fixedSize()

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text("项目概览")
                        .font(.callout)
                        .foregroundStyle(Color.textTertiary)
                    Text(statusText)
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text("状态")
                        .font(.callout)
                        .foregroundStyle(Color.textTertiary)
                    Text(detailText)
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer(minLength: 12)

                Label("打开公共空间", systemImage: "chevron.right")
                    .font(.callout.bold())
                    .foregroundStyle(Color.publicTeal)
                    .fixedSize()
            }
        }
    }
}
