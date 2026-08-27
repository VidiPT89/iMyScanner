import SwiftUI

struct AboutView: View {
    let appVersion: String

    private let websiteURL = URL(string: "https://ividi.dev")!
    private let githubURL = URL(string: "https://github.com/VidiPT89")!

    var body: some View {
        ZStack {
            AppColor.backgroundBlack.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [AppColor.accentOrange, AppColor.accentAmber], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .padding(.top, 32)

                Text("iMyScanner")
                    .font(AppTypography.title())

                Text(String(format: L("about.version"), appVersion))
                    .font(AppTypography.caption())
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    infoRow(titleKey: "about.developer", value: "David Arsénio Martins")
                    Link(destination: websiteURL) {
                        infoLinkRow(titleKey: "about.website", value: "ividi.dev")
                    }
                    Link(destination: githubURL) {
                        infoLinkRow(titleKey: "about.github", value: "github.com/VidiPT89")
                    }
                }
                .padding(AppMetrics.standardPadding)
                .background(AppColor.surfaceDark.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
                .padding(.horizontal, AppMetrics.standardPadding)

                Spacer()
            }
        }
        .navigationTitle(L("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(titleKey: String, value: String) -> some View {
        HStack {
            Text(L(titleKey))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(AppTypography.body())
    }

    private func infoLinkRow(titleKey: String, value: String) -> some View {
        HStack {
            Text(L(titleKey))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColor.accentOrange)
        }
        .font(AppTypography.body())
    }
}
