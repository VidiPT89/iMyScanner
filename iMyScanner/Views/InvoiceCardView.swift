import SwiftUI

/// What the AT QR code on a scanned invoice says, shown above the document's pages:
/// seller, date, amounts, and whether it reaches the user's e-Fatura.
struct InvoiceCardView: View {
    let invoice: FiscalInvoice
    let onCategoryChange: (ExpenseCategory) -> Void
    @AppStorage(FiscalQRService.userNIFKey) private var userNIF = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(L("invoice.title"), systemImage: "qrcode")
                    .font(AppTypography.headline())
                    .foregroundStyle(AppColor.accentPrimary)
                Spacer()
                Text(InvoiceFormat.euros(invoice.signedTotal))
                    .font(AppTypography.title())
                    .accessibilityIdentifier("invoice.total")
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row(L("invoice.issuer"), InvoiceFormat.nif(invoice.issuerNIF))
                row(L("invoice.date"), InvoiceFormat.date(invoice))
                row(L("invoice.document"), invoice.documentNumber.isEmpty ? invoice.documentType : invoice.documentNumber)
                row(L("invoice.vat"), InvoiceFormat.euros(invoice.vat))
                row("ATCUD", invoice.atcud)
            }
            .font(AppTypography.caption())

            statusBanner

            if !invoice.amountsAreConsistent {
                banner(L("invoice.inconsistent"), systemImage: "exclamationmark.triangle.fill", color: .orange)
            }

            Menu {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Button {
                        onCategoryChange(category)
                    } label: {
                        Label(L(category.titleKey), systemImage: category == invoice.category ? "checkmark" : category.systemImage)
                    }
                }
            } label: {
                HStack {
                    Text(L("invoice.category"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(L(invoice.category.titleKey), systemImage: invoice.category.systemImage)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(AppTypography.body())
            }
            .accessibilityIdentifier("invoice.category")
        }
        .padding(AppMetrics.standardPadding)
        .background(AppColor.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius, style: .continuous))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch invoice.deductionStatus(userNIF: userNIF) {
        case .counts:
            banner(L("invoice.status.counts"), systemImage: "checkmark.seal.fill", color: .green)
        case .noBuyerNIF:
            banner(L("invoice.status.noNIF"), systemImage: "exclamationmark.circle.fill", color: .orange)
        case .otherNIF(let nif):
            banner(String(format: L("invoice.status.otherNIF"), InvoiceFormat.nif(nif)), systemImage: "person.crop.circle.badge.exclamationmark", color: .red)
        case .unknown:
            banner(String(format: L("invoice.status.unknown"), InvoiceFormat.nif(invoice.buyerNIF)), systemImage: "info.circle.fill", color: .secondary)
        }
    }

    private func banner(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(AppTypography.caption())
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius, style: .continuous))
            .accessibilityIdentifier("invoice.status")
    }
}
