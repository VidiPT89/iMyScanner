import SwiftUI

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var page = 0

    private let pages: [(icon: String, titleKey: String, subtitleKey: String)] = [
        ("doc.viewfinder", "onboarding.scan.title", "onboarding.scan.subtitle"),
        ("crop", "onboarding.edit.title", "onboarding.edit.subtitle"),
        ("wand.and.stars", "onboarding.enhance.title", "onboarding.enhance.subtitle"),
        ("lock.shield", "onboarding.privacy.title", "onboarding.privacy.subtitle")
    ]

    var body: some View {
        ZStack {
            AppColor.backgroundBlack.ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(
                            icon: pages[index].icon,
                            title: L(pages[index].titleKey),
                            subtitle: L(pages[index].subtitleKey)
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut, value: page)

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        withAnimation { isCompleted = true }
                    }
                } label: {
                    Text(page < pages.count - 1 ? L("onboarding.next") : L("onboarding.start"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppMetrics.standardPadding)

                if page < pages.count - 1 {
                    Button(L("onboarding.skip")) {
                        withAnimation { isCompleted = true }
                    }
                    .font(AppTypography.caption())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                }
            }
            .padding(.vertical, 32)
        }
    }
}

private struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 84, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.accentOrange, AppColor.accentAmber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(AppTypography.title())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(AppTypography.body())
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
