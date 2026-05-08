import Foundation

enum TransactionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case transfer
    case bankPayout
    case bankCollect
    case rent
    case salary
    case fee
    case gameStart
    case reversal
    case custom

    /// Виды, доступные пользователю в Picker'е перевода. `gameStart` и `reversal`
    /// генерируются сервисом, в UI выбора их быть не должно.
    static let userSelectable: [TransactionKind] = [
        .transfer, .bankPayout, .bankCollect, .rent, .salary, .fee, .custom,
    ]

    var displayName: String {
        switch self {
        case .transfer: String(localized: "Перевод")
        case .bankPayout: String(localized: "Из банка")
        case .bankCollect: String(localized: "В банк")
        case .rent: String(localized: "Аренда")
        case .salary: String(localized: "Зарплата")
        case .fee: String(localized: "Штраф")
        case .gameStart: String(localized: "Старт игры")
        case .reversal: String(localized: "Возврат")
        case .custom: String(localized: "Другое")
        }
    }

    var systemImageName: String {
        switch self {
        case .transfer: "arrow.left.arrow.right"
        case .bankPayout: "building.columns"
        case .bankCollect: "building.columns.fill"
        case .rent: "house"
        case .salary: "dollarsign.arrow.circlepath"
        case .fee: "exclamationmark.triangle"
        case .gameStart: "flag.checkered"
        case .reversal: "arrow.uturn.backward"
        case .custom: "ellipsis.circle"
        }
    }
}
