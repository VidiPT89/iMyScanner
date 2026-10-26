import SwiftUI

/// The year's scanned invoices totalled by e-Fatura category, so the user can
/// compare them with the Portal das Finanças before the IRS return.
struct ExpensesView: View {
    private struct CSVFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    let invoices: [(title: String, invoice: FiscalInvoice)]
    @Environment(\.dismiss) private var dismiss
    @AppStorage(FiscalQRService.userNIFKey) private var userNIF = ""
    @State private var year: Int
    @State private var csvFile: CSVFile?
    @State private var exportFailed = false

    init(invoices: [(title: String, invoice: FiscalInvoice)]) {
        self.invoices = invoices
        let latest = invoices.compactMap(\.invoice.year).max() ?? Calendar.current.component(.year, from: Date())
        _year = State(initialValue: latest)
    }

    private var years: [Int] {
        Array(Set(invoices.compactMap(\.invoice.year) + [year])).sorted(by: >)
    }

    private var summary: ExpenseSummary {
        ExpenseSummary(year: year, invoices: invoices.map(\.invoice), userNIF: userNIF)
    }

    var body: some View {
        NavigationStack {
            List {
                if years.count > 1 {
                    Picker(L("expenses.year"), selection: $year) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                }

                Section {
                    HStack {
                        Text(L("expenses.total"))
                        Spacer()
                        Text(InvoiceFormat.euros(summary.total))
                            .font(AppTypography.headline())
                            .accessibilityIdentifier("expenses.total")
                    }
                    if summary.notCounting > 0 {
                        Label(String(format: L("expenses.notCounting"), summary.notCounting), systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.caption())
                            .foregroundStyle(.orange)
                    }
                    if !NIF.isValid(userNIF) {
                        Label(L("expenses.setNIF"), systemImage: "info.circle")
                            .font(AppTypography.caption())
                            .foregroundStyle(.secondary)
                    }
                }

                Section(L("expenses.byCategory")) {
                    if summary.lines.isEmpty {
                        Text(L("expenses.empty"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(summary.lines) { line in
                        HStack {
                            Label(L(line.category.titleKey), systemImage: line.category.systemImage)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(InvoiceFormat.euros(line.total))
                                Text(line.count == 1 ? L("expenses.invoice.singular") : String(format: L("expenses.invoice.plural"), line.count))
                                    .font(AppTypography.caption())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Text(L("expenses.disclaimer"))
                        .font(AppTypography.caption())
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("expenses.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("action.done")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportCSV()
                    } label: {
                        Label(L("expenses.exportCSV"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(summary.lines.isEmpty)
                }
            }
            .sheet(item: $csvFile) { file in
                ActivityShareSheet(items: [file.url])
            }
            .alert(L("document.exportFailed"), isPresented: $exportFailed) {
                Button(L("action.close"), role: .cancel) {}
            }
        }
    }

    private func exportCSV() {
        let header = ["expenses.csv.date", "expenses.csv.title", "expenses.csv.issuer", "expenses.csv.buyer", "expenses.csv.type",
                      "expenses.csv.number", "ATCUD", "expenses.csv.category", "expenses.csv.base", "expenses.csv.vat",
                      "expenses.csv.total"].map { $0.hasPrefix("expenses.") ? L($0) : $0 }
        let csv = ExpenseSummary.csv(for: invoices, year: year, decimalComma: L("format.locale").hasPrefix("pt"),
                                     header: header, categoryName: { L($0.titleKey) })
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent(String(format: L("expenses.csv.fileName"), year) + ".csv")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // A byte-order mark makes Excel read the accents as UTF-8.
            try Data(("\u{FEFF}" + csv).utf8).write(to: url, options: .atomic)
            csvFile = CSVFile(url: url)
        } catch {
            exportFailed = true
        }
    }
}
