import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage(FiscalQRService.userNIFKey) private var userNIF = ""

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

                    if viewModel.showRestartHint {
                        Text(L("settings.language.restartHint"))
                            .font(AppTypography.caption())
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField(L("settings.nif.placeholder"), text: $userNIF)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("settings.nif")
                } header: {
                    Text(L("settings.nif"))
                } footer: {
                    if !userNIF.isEmpty && !NIF.isValid(userNIF) {
                        Text(L("settings.nif.invalid")).foregroundStyle(.red)
                    } else {
                        Text(L("settings.nif.footer"))
                    }
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
