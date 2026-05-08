import SwiftData
import SwiftUI

@main
struct Monopoly_TrackerApp: App {
    @State private var container: AppContainer
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("languageMode") private var languageMode: LanguageMode = .system

    init() {
        let schema = Schema([
            Game.self,
            Player.self,
            Transaction.self,
        ])
        let modelContainer = Self.makeContainer(schema: schema)
        _container = State(initialValue: AppContainer(modelContainer: modelContainer))

        // Применяем сохранённый язык до сборки первого view, чтобы не было моргания.
        let stored = UserDefaults.standard.string(forKey: "languageMode")
        let initialLanguage = LanguageMode(rawValue: stored ?? "") ?? .system
        BundleLanguageOverride.apply(initialLanguage.resourceCode)
    }

    /// Пытается создать дисковый контейнер, при любой ошибке (например,
    /// sandbox-проблемы при запуске под тест-хостом) откатывается на in-memory.
    private static func makeContainer(schema: Schema) -> ModelContainer {
        let onDisk = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [onDisk]) {
            return container
        }
        let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            fatalError("Не удалось создать ни дисковый, ни in-memory ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(\.locale, currentLocale)
                .preferredColorScheme(appearanceMode.preferredColorScheme)
                .id(languageMode) // принудительный пересбор Text после смены языка
                .onChange(of: languageMode) { _, newMode in
                    BundleLanguageOverride.apply(newMode.resourceCode)
                }
        }
        .modelContainer(container.modelContainer)
    }

    private var currentLocale: Locale {
        if let code = languageMode.resourceCode { return Locale(identifier: code) }
        return .autoupdatingCurrent
    }
}
