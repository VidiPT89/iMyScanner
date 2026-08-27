import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L("settings.appearance")) {
                    Picker(L("settings.theme"), selection: $viewModel.themeOption) {
                        Text(L("settings.theme.dark")).tag(AppThemeOption.dark)
                        Text(L("settings.theme.light")).tag(AppThemeOption.light)
                        Text(L("settings.theme.system")).tag(AppThemeOption.system)
                    }
                    .pickerStyle(.segmented)
                }

                Section(L("settings.language")) {
                    Picker(L("settings.language"), selection: $viewModel.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    NavigationLink {
                        AboutView(appVersion: viewModel.appVersion)
                    } label: {
                        Label(L("settings.about"), systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("action.done")) { dismiss() }
                }
            }
        }
    }
}
