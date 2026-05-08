import Foundation

typealias Money = Decimal

// MARK: - Format styles

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    /// Денежный формат для всего приложения. Локаль зафиксирована — знак `$`
    /// и запятая-разделитель тысяч независимо от выбранного UI-языка.
    static var monopolyMoney: Decimal.FormatStyle.Currency {
        .currency(code: "USD")
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "en_US"))
    }
}

extension FormatStyle where Self == Decimal.FormatStyle {
    /// Чисто числовой формат для текстового поля ввода — цифры с разделителями
    /// тысяч, без знака валюты (он рисуется отдельно).
    static var monopolyDigits: Decimal.FormatStyle {
        Decimal.FormatStyle.number
            .grouping(.automatic)
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "en_US"))
    }
}

// MARK: - Parsing

extension Money {
    /// Парсит свободно введённое пользователем число — оставляет только цифры
    /// (запятые, пробелы, любые разделители тысяч игнорируются как форматирование).
    /// В Монополии нет дробных сумм, поэтому десятичный разделитель тоже не нужен.
    /// Argument label `parsing:` намеренно не совпадает с Foundation-овским
    /// `Decimal(string:)` — иначе Money == Decimal и `Decimal(string: cleaned)`
    /// внутри инициализатора уйдёт в бесконечную рекурсию.
    init?(parsing input: String) {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty, let value = Decimal(string: digits, locale: nil) else { return nil }
        self = value
    }
}
