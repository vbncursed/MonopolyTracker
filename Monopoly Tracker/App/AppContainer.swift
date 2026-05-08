import Foundation
import SwiftData
import SwiftUI

/// Композиционный корень. Создаёт `LedgerService` поверх общего `ModelContainer`.
/// Прокидывается через `@Environment(AppContainer.self)`.
@MainActor
@Observable
final class AppContainer {
    let modelContainer: ModelContainer
    let ledger: LedgerService

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.ledger = LiveLedgerService(container: modelContainer)
    }
}
