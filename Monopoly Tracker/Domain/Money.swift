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
