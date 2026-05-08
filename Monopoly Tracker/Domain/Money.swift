import Foundation

typealias Money = Decimal

extension Money {
    static let zero: Money = 0

    static func monopoly(_ value: Int) -> Money {
        Money(value)
    }
}

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    static var monopolyMoney: Decimal.FormatStyle.Currency {
        .currency(code: "USD")
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "en_US"))
    }
}

extension FormatStyle where Self == Decimal.FormatStyle {
    /// Формат для текстового поля ввода суммы: только цифры с разделителями тысяч,
    /// без знака валюты (он рисуется отдельно). Локаль зафиксирована — запятая
    /// как разделитель тысяч независимо от выбранного UI-языка.
    static var monopolyDigits: Decimal.FormatStyle {
        Decimal.FormatStyle.number
            .grouping(.automatic)
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "en_US"))
    }
}
