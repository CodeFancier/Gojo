import SwiftUI
import GojoCore

struct PendingMemberCard: View {
    let member: PendingCodingSpaceMember

    private var operationDescription: String {
        switch member.mode {
        case .git:
            "正在克隆…"
        case .symlink:
            "正在创建软链接…"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Image(systemName: "shippingbox")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.textSecondary)
                ProgressView()
                    .controlSize(.small)
                    .offset(x: 9, y: 8)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.folderName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(member.folderName)
                Text(operationDescription)
                    .font(.callout)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.cardStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.folderName)，\(operationDescription)")
    }
}
