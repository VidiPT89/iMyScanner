import Foundation

/// Portuguese tax numbers (NIF/NIPC): nine digits whose last one is a mod-11 check digit.
enum NIF {
    /// The number invoices carry when the buyer gave no NIF ("consumidor final").
    static let finalConsumer = "999999990"

    /// Strips spaces and an optional "PT" prefix so "PT 234 567 899" compares equal to "234567899".
    static func normalized(_ value: String) -> String {
        var digits = value.uppercased().filter { !$0.isWhitespace }
        if digits.hasPrefix("PT") { digits.removeFirst(2) }
        return digits
    }

    static func isValid(_ value: String) -> Bool {
        let digits = normalized(value).compactMap(\.wholeNumberValue)
        guard digits.count == 9, normalized(value).count == 9, digits[0] != 0 else { return false }
        let sum = digits.prefix(8).enumerated().reduce(0) { $0 + $1.element * (9 - $1.offset) }
        let remainder = sum % 11
        return digits[8] == (remainder < 2 ? 0 : 11 - remainder)
    }
}

/// e-Fatura expense categories that count towards IRS deductions, plus "other".
/// The QR code doesn't say which one applies, so the user picks it per invoice.
enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case generalFamily, health, education, housing, elderlyCare, vatBenefit, other

    var titleKey: String { "expense.category.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .generalFamily: return "house"
        case .health: return "cross.case"
        case .education: return "graduationcap"
        case .housing: return "key"
        case .elderlyCare: return "figure.and.child.holdinghands"
        case .vatBenefit: return "percent"
        case .other: return "tray"
        }
    }
}

/// Whether an invoice can count towards the user's IRS deductions.
enum DeductionStatus: Equatable {
    /// The buyer NIF is the user's own.
    case counts
    /// Issued to "consumidor final" (no NIF): it never reaches the user's e-Fatura.
    case noBuyerNIF
    /// Issued to someone else's NIF.
    case otherNIF(String)
    /// The user hasn't entered their NIF in Settings, so it can't be checked.
    case unknown
}

/// The data in the mandatory ATCUD QR code printed on Portuguese invoices and
/// receipts (Portaria n.º 195/2020): fields `X:value` separated by `*`.
struct FiscalInvoice: Codable, Equatable, Sendable {
    var issuerNIF: String
    var buyerNIF: String
    var buyerCountry: String
    /// FT (fatura), FS (fatura simplificada), FR (fatura-recibo), NC (nota de crédito)…
    var documentType: String
    /// Issue date as printed in the QR code (`yyyyMMdd`).
    var issueDate: String
    var documentNumber: String
    var atcud: String
    /// Taxable amount per VAT rate, summed over mainland, Azores and Madeira.
    var taxableBase: Decimal
    var vat: Decimal
    /// Amounts outside VAT: exempt (I2/J2/K2) and not subject (L).
    var exemptAmount: Decimal
    var stampDuty: Decimal
    var totalTaxes: Decimal
    var grossTotal: Decimal
    var withholding: Decimal
    var category: ExpenseCategory = .generalFamily

    /// Parses a scanned QR payload. Returns nil for anything that isn't an AT
    /// invoice code (a URL, a Wi-Fi code, a truncated read).
    static func parse(_ payload: String) -> FiscalInvoice? {
        var fields: [String: String] = [:]
        for part in payload.split(separator: "*", omittingEmptySubsequences: true) {
            guard let colon = part.firstIndex(of: ":") else { continue }
            fields[String(part[..<colon])] = String(part[part.index(after: colon)...])
        }
        guard let issuer = fields["A"], NIF.isValid(issuer),
              let buyer = fields["B"], let type = fields["D"],
              let date = fields["F"], date.count == 8, date.allSatisfy(\.isNumber),
              let atcud = fields["H"], let total = fields["O"].flatMap(amount) else { return nil }

        func sum(_ keys: [String]) -> Decimal { keys.compactMap { fields[$0].flatMap(amount) }.reduce(0, +) }
        let regions = ["I", "J", "K"]
        let bases = regions.flatMap { ["\($0)3", "\($0)5", "\($0)7"] }
        let taxes = regions.flatMap { ["\($0)4", "\($0)6", "\($0)8"] }
        let vat = sum(taxes)
        let stamp = sum(["M"])

        return FiscalInvoice(
            issuerNIF: issuer, buyerNIF: buyer, buyerCountry: fields["C"] ?? "PT",
            documentType: type, issueDate: date, documentNumber: fields["G"] ?? "", atcud: atcud,
            taxableBase: sum(bases), vat: vat, exemptAmount: sum(regions.map { "\($0)2" } + ["L"]),
            stampDuty: stamp, totalTaxes: fields["N"].flatMap(amount) ?? vat + stamp,
            grossTotal: total, withholding: sum(["P"])
        )
    }

    private static func amount(_ text: String) -> Decimal? {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    var year: Int? { Int(issueDate.prefix(4)) }

    var date: Date? {
        var components = DateComponents()
        components.year = year
        components.month = Int(issueDate.dropFirst(4).prefix(2))
        components.day = Int(issueDate.suffix(2))
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// Credit notes reduce the year's spending instead of adding to it.
    var signedTotal: Decimal { documentType == "NC" ? -grossTotal : grossTotal }

    /// True when the amounts add up, so a misread QR code is flagged rather than
    /// silently totalled. Allows one cent of rounding per component.
    var amountsAreConsistent: Bool {
        let difference = taxableBase + vat + exemptAmount + stampDuty - grossTotal
        return abs(difference) <= 0.03 && abs(vat + stampDuty - totalTaxes) <= 0.02
    }

    func deductionStatus(userNIF: String?) -> DeductionStatus {
        let buyer = NIF.normalized(buyerNIF)
        if buyer == NIF.finalConsumer || buyer.isEmpty { return .noBuyerNIF }
        guard let userNIF, NIF.isValid(userNIF) else { return .unknown }
        return buyer == NIF.normalized(userNIF) ? .counts : .otherNIF(buyer)
    }
}

/// One year's invoices grouped by e-Fatura category, for the Expenses screen and CSV export.
struct ExpenseSummary {
    struct Line: Identifiable {
        let category: ExpenseCategory
        let count: Int
        let total: Decimal
        var id: ExpenseCategory { category }
    }

    let year: Int
    let lines: [Line]
    let total: Decimal
    /// Invoices that won't reach the user's e-Fatura (no NIF or someone else's).
    let notCounting: Int

    init(year: Int, invoices: [FiscalInvoice], userNIF: String?) {
        self.year = year
        let ofYear = invoices.filter { $0.year == year }
        lines = ExpenseCategory.allCases.compactMap { category in
            let matching = ofYear.filter { $0.category == category }
            guard !matching.isEmpty else { return nil }
            return Line(category: category, count: matching.count, total: matching.map(\.signedTotal).reduce(0, +))
        }
        total = ofYear.map(\.signedTotal).reduce(0, +)
        notCounting = ofYear.filter {
            switch $0.deductionStatus(userNIF: userNIF) {
            case .noBuyerNIF, .otherNIF: return true
            case .counts, .unknown: return false
            }
        }.count
    }

    /// Semicolon-separated rows (what Excel and Numbers expect in Portugal), one per invoice.
    static func csv(for documents: [(title: String, invoice: FiscalInvoice)], year: Int, decimalComma: Bool,
                    header: [String], categoryName: (ExpenseCategory) -> String) -> String {
        func number(_ value: Decimal) -> String {
            let text = NSDecimalNumber(decimal: value).stringValue
            return decimalComma ? text.replacingOccurrences(of: ".", with: ",") : text
        }
        func cell(_ text: String) -> String {
            text.contains(where: { ";\"\n".contains($0) }) ? "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"" : text
        }
        let rows = documents.filter { $0.invoice.year == year }.sorted { $0.invoice.issueDate < $1.invoice.issueDate }.map { entry in
            let invoice = entry.invoice
            let date = "\(invoice.issueDate.prefix(4))-\(invoice.issueDate.dropFirst(4).prefix(2))-\(invoice.issueDate.suffix(2))"
            return [date, entry.title, invoice.issuerNIF, invoice.buyerNIF, invoice.documentType, invoice.documentNumber,
                    invoice.atcud, categoryName(invoice.category), number(invoice.taxableBase), number(invoice.vat),
                    number(invoice.signedTotal)].map(cell).joined(separator: ";")
        }
        return ([header.map(cell).joined(separator: ";")] + rows).joined(separator: "\n") + "\n"
    }
}
