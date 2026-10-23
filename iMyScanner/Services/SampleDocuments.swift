#if DEBUG
import UIKit

/// Debug-only fixtures for the UI tests and App Store screenshots. Launching with
/// `-uiTestSampleData` replaces the library with a few realistic documents in the
/// app's current language. Never compiled into Release builds.
enum SampleDocuments {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestSampleData")
    }

    static func install(into storage: DocumentStorageService, portuguese pt: Bool) {
        // Clearing the index first also deletes the previous run's page images.
        storage.saveDocuments([])
        let invoices = DocumentFolder(name: pt ? "Faturas" : "Invoices", createdAt: Date(timeIntervalSinceNow: -300))
        let home = DocumentFolder(name: pt ? "Casa" : "Home", createdAt: Date(timeIntervalSinceNow: -200))
        let work = DocumentFolder(name: pt ? "Trabalho" : "Work", createdAt: Date(timeIntervalSinceNow: -100))
        storage.saveFolders([invoices, home, work])

        func pages(_ images: [UIImage], filter: PageFilter = .original) -> [ScanPage] {
            images.compactMap { image in
                storage.saveImage(image).map { ScanPage(originalFileName: $0, editedFileName: $0, filter: filter) }
            }
        }
        func document(_ title: String, _ pages: [ScanPage], folder: DocumentFolder?, tags: [String], minutesAgo: Double) -> ScanDocument {
            let date = Date(timeIntervalSinceNow: -minutesAgo * 60)
            return ScanDocument(title: title, pages: pages, createdAt: date, updatedAt: date, folderId: folder?.id, tags: tags)
        }

        let documents = [
            document(pt ? "Fatura da eletricidade" : "Electricity bill",
                     pages([invoice(pt: pt), invoiceDetails(pt: pt)]),
                     folder: invoices, tags: pt ? ["casa", "2026"] : ["home", "2026"], minutesAgo: 5),
            document(pt ? "Contrato de arrendamento" : "Lease agreement",
                     pages([letter(pt: pt, page: 1), letter(pt: pt, page: 2), letter(pt: pt, page: 3)]),
                     folder: home, tags: pt ? ["contratos"] : ["contracts"], minutesAgo: 90),
            document(pt ? "Recibo do supermercado" : "Grocery receipt",
                     pages([receipt(pt: pt)], filter: .enhance),
                     folder: invoices, tags: [], minutesAgo: 60 * 26),
            document(pt ? "Notas da reunião" : "Meeting notes",
                     pages([notes(pt: pt)], filter: .blackAndWhite),
                     folder: work, tags: pt ? ["projeto"] : ["project"], minutesAgo: 60 * 50)
        ]
        storage.saveDocuments(documents)
    }

    // MARK: - Page artwork

    private static let pageSize = CGSize(width: 1240, height: 1754)
    private static let ink = UIColor(red: 0.13, green: 0.14, blue: 0.17, alpha: 1)
    private static let muted = UIColor(red: 0.42, green: 0.44, blue: 0.48, alpha: 1)
    private static let accent = UIColor(red: 0.16, green: 0.33, blue: 0.62, alpha: 1)

    private static func render(size: CGSize = pageSize, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.985, green: 0.98, blue: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(context.cgContext)
        }
    }

    private static func text(_ string: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight = .regular,
                             color: UIColor = ink, width: CGFloat = 1000, align: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineSpacing = size * 0.35
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style
        ]
        (string as NSString).draw(with: CGRect(x: point.x, y: point.y, width: width, height: 1600),
                                  options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
    }

    private static func rule(y: CGFloat, from x: CGFloat = 110, to end: CGFloat = 1130, color: UIColor = muted) {
        color.withAlphaComponent(0.35).setFill()
        UIRectFill(CGRect(x: x, y: y, width: end - x, height: 3))
    }

    private static func invoice(pt: Bool) -> UIImage {
        render { _ in
            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: 110, y: 110, width: 90, height: 90), cornerRadius: 20).fill()
            text("Luz & Energia, S.A.", at: CGPoint(x: 230, y: 118), size: 40, weight: .bold)
            text(pt ? "Rua das Flores 21, 1200-192 Lisboa" : "21 Flower Street, Lisbon", at: CGPoint(x: 230, y: 168), size: 26, color: muted)
            text(pt ? "FATURA" : "INVOICE", at: CGPoint(x: 110, y: 300), size: 64, weight: .heavy, color: accent)
            text(pt ? "N.º FT 2026/10482\nData: 23/10/2026\nVencimento: 15/11/2026" : "No. FT 2026/10482\nDate: 23 Oct 2026\nDue: 15 Nov 2026",
                 at: CGPoint(x: 110, y: 400), size: 30, color: muted)
            text(pt ? "Cliente\nAna Ferreira\nAv. da Liberdade 110, Lisboa" : "Customer\nAna Ferreira\n110 Liberty Avenue, Lisbon",
                 at: CGPoint(x: 700, y: 400), size: 30, width: 430)
            rule(y: 600)
            let rows = pt
                ? [("Descrição", "Valor"), ("Energia ativa (312 kWh)", "48,36 €"), ("Potência contratada", "12,90 €"),
                   ("Taxa de exploração", "0,07 €"), ("Contribuição audiovisual", "2,85 €"), ("IVA 23%", "14,75 €")]
                : [("Description", "Amount"), ("Active energy (312 kWh)", "€48.36"), ("Contracted power", "€12.90"),
                   ("Operating fee", "€0.07"), ("Audiovisual levy", "€2.85"), ("VAT 23%", "€14.75")]
            for (index, row) in rows.enumerated() {
                let y = 640 + CGFloat(index) * 78
                let weight: UIFont.Weight = index == 0 ? .semibold : .regular
                text(row.0, at: CGPoint(x: 110, y: y), size: 32, weight: weight, color: index == 0 ? muted : ink)
                text(row.1, at: CGPoint(x: 830, y: y), size: 32, weight: weight, color: index == 0 ? muted : ink, width: 300, align: .right)
                if index > 0 { rule(y: y + 60) }
            }
            accent.withAlphaComponent(0.08).setFill()
            UIBezierPath(roundedRect: CGRect(x: 110, y: 1150, width: 1020, height: 130), cornerRadius: 18).fill()
            text(pt ? "Total a pagar" : "Total due", at: CGPoint(x: 150, y: 1190), size: 40, weight: .bold)
            text(pt ? "78,93 €" : "€78.93", at: CGPoint(x: 790, y: 1186), size: 46, weight: .heavy, color: accent, width: 300, align: .right)
            text(pt ? "Pagamento por Multibanco\nEntidade 21312  ·  Referência 482 105 337" : "Pay by bank transfer\nIBAN PT50 0002 0123 1234 5678 9015 4",
                 at: CGPoint(x: 110, y: 1360), size: 28, color: muted)
        }
    }

    private static func invoiceDetails(pt: Bool) -> UIImage {
        render { context in
            text(pt ? "Consumo dos últimos 6 meses" : "Usage over the last 6 months", at: CGPoint(x: 110, y: 130), size: 44, weight: .bold)
            let values: [CGFloat] = [260, 238, 205, 221, 284, 312]
            let months = pt ? ["Mai", "Jun", "Jul", "Ago", "Set", "Out"] : ["May", "Jun", "Jul", "Aug", "Sep", "Oct"]
            for (index, value) in values.enumerated() {
                let x = 150 + CGFloat(index) * 160
                (index == values.count - 1 ? accent : accent.withAlphaComponent(0.4)).setFill()
                UIBezierPath(roundedRect: CGRect(x: x, y: 760 - value * 1.6, width: 100, height: value * 1.6), cornerRadius: 12).fill()
                text(months[index], at: CGPoint(x: x, y: 780), size: 28, color: muted, width: 100, align: .center)
            }
            rule(y: 760)
            text(pt ? "Média mensal: 253 kWh\nEste mês: 312 kWh (+10%)" : "Monthly average: 253 kWh\nThis month: 312 kWh (+10%)",
                 at: CGPoint(x: 110, y: 900), size: 34)
            text(pt ? "Dicas para poupar\n• Aproveite o horário de vazio para máquinas de lavar.\n• Desligue os aparelhos em modo de espera.\n• Prefira lâmpadas LED."
                    : "Tips to save energy\n• Run washing machines during off-peak hours.\n• Switch off devices on standby.\n• Prefer LED light bulbs.",
                 at: CGPoint(x: 110, y: 1080), size: 32)
            _ = context
        }
    }

    private static func letter(pt: Bool, page: Int) -> UIImage {
        let body = pt
            ? "Entre os outorgantes acima identificados é celebrado o presente contrato de arrendamento para habitação, que se rege pelas cláusulas seguintes e, no omisso, pela lei aplicável. O imóvel destina-se exclusivamente a habitação própria e permanente do segundo outorgante e do seu agregado familiar. A renda mensal é paga até ao dia oito de cada mês, por transferência bancária para a conta indicada pelo senhorio."
            : "Between the parties identified above, this residential lease agreement is entered into, governed by the following clauses and, where silent, by applicable law. The property is to be used exclusively as the permanent home of the tenant and their household. Monthly rent is paid by the eighth day of each month, by bank transfer to the account indicated by the landlord."
        return render { _ in
            if page == 1 {
                text(pt ? "CONTRATO DE ARRENDAMENTO" : "LEASE AGREEMENT", at: CGPoint(x: 110, y: 150), size: 52, weight: .heavy, width: 1020, align: .center)
                text(pt ? "Prazo certo · Habitação" : "Fixed term · Residential", at: CGPoint(x: 110, y: 230), size: 30, color: muted, width: 1020, align: .center)
            } else {
                text(pt ? "Cláusula \(page + 2).ª" : "Clause \(page + 2)", at: CGPoint(x: 110, y: 150), size: 40, weight: .bold)
            }
            text(body + "\n\n" + body, at: CGPoint(x: 110, y: page == 1 ? 360 : 260), size: 32, width: 1020)
            if page == 3 {
                rule(y: 1450, from: 110, to: 520, color: ink)
                rule(y: 1450, from: 720, to: 1130, color: ink)
                text(pt ? "O senhorio" : "Landlord", at: CGPoint(x: 110, y: 1470), size: 28, color: muted, width: 410, align: .center)
                text(pt ? "O arrendatário" : "Tenant", at: CGPoint(x: 720, y: 1470), size: 28, color: muted, width: 410, align: .center)
            }
            text("\(page) / 3", at: CGPoint(x: 110, y: 1640), size: 26, color: muted, width: 1020, align: .center)
        }
    }

    private static func receipt(pt: Bool) -> UIImage {
        render(size: CGSize(width: 900, height: 1754)) { _ in
            text(pt ? "MERCADO DO BAIRRO" : "CORNER MARKET", at: CGPoint(x: 60, y: 110), size: 46, weight: .heavy, width: 780, align: .center)
            text(pt ? "NIF 509 123 456 · Cascais" : "VAT 509 123 456 · Cascais", at: CGPoint(x: 60, y: 180), size: 26, color: muted, width: 780, align: .center)
            let items = pt
                ? [("Pão de forma", "1,89"), ("Leite meio-gordo x6", "4,74"), ("Maçãs 1,2 kg", "2,28"), ("Café moído", "3,99"),
                   ("Azeite virgem extra", "6,49"), ("Queijo flamengo", "2,79"), ("Água 6 x 1,5 L", "1,74")]
                : [("Sliced bread", "1.89"), ("Milk x6", "4.74"), ("Apples 1.2 kg", "2.28"), ("Ground coffee", "3.99"),
                   ("Extra virgin olive oil", "6.49"), ("Cheese slices", "2.79"), ("Water 6 x 1.5 L", "1.74")]
            for (index, item) in items.enumerated() {
                let y = 300 + CGFloat(index) * 70
                text(item.0, at: CGPoint(x: 60, y: y), size: 32, width: 560)
                text(item.1, at: CGPoint(x: 600, y: y), size: 32, width: 240, align: .right)
            }
            rule(y: 820, from: 60, to: 840)
            text("TOTAL", at: CGPoint(x: 60, y: 850), size: 44, weight: .heavy)
            text(pt ? "23,92 €" : "€23.92", at: CGPoint(x: 540, y: 850), size: 44, weight: .heavy, width: 300, align: .right)
            text(pt ? "Cartão · 23/10/2026 18:42\nObrigado pela preferência!" : "Card · 23 Oct 2026 18:42\nThank you for shopping with us!",
                 at: CGPoint(x: 60, y: 960), size: 28, color: muted, width: 780, align: .center)
        }
    }

    private static func notes(pt: Bool) -> UIImage {
        render { _ in
            text(pt ? "Reunião de planeamento" : "Planning meeting", at: CGPoint(x: 110, y: 140), size: 52, weight: .bold)
            text(pt ? "23 de outubro · Equipa de produto" : "23 October · Product team", at: CGPoint(x: 110, y: 215), size: 30, color: muted)
            text(pt ? "Decisões\n• Lançar a versão 1.0 em novembro.\n• Testes com 10 utilizadores na próxima semana.\n• Rever os textos em português e inglês.\n\nPróximos passos\n• Ana: preparar as capturas da loja.\n• Rui: fechar a política de privacidade.\n• David: enviar para revisão."
                    : "Decisions\n• Ship version 1.0 in November.\n• Test with 10 users next week.\n• Review the Portuguese and English copy.\n\nNext steps\n• Ana: prepare the store screenshots.\n• Rui: finalise the privacy policy.\n• David: submit for review.",
                 at: CGPoint(x: 110, y: 340), size: 36, width: 1020)
        }
    }
}
#endif
