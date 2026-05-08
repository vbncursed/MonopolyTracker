import Foundation
import ObjectiveC

/// Подменяет `Bundle.main.localizedString(forKey:value:table:)` на лету,
/// чтобы выбранный пользователем язык применялся без перезапуска.
///
/// SwiftUI кэширует строки в `Text`, поэтому вызывающая сторона должна
/// выставить `.id(languageMode)` на корне дерева, чтобы заставить
/// пересборку всех `Text` после смены языка.
enum BundleLanguageOverride {
    private static var bundleAssociationKey: UInt8 = 0
    private static var didSwizzle = false

    /// Применяет выбранный язык. nil — снимает override и возвращает системный.
    static func apply(_ languageCode: String?) {
        ensureSwizzled()
        if let code = languageCode,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            objc_setAssociatedObject(
                Bundle.main,
                &bundleAssociationKey,
                langBundle,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            objc_setAssociatedObject(
                Bundle.main,
                &bundleAssociationKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private static func ensureSwizzled() {
        guard !didSwizzle else { return }
        didSwizzle = true

        let original = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzled = #selector(Bundle.mt_overriddenLocalizedString(forKey:value:table:))
        guard
            let originalMethod = class_getInstanceMethod(Bundle.self, original),
            let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    fileprivate static func overrideBundle(for bundle: Bundle) -> Bundle? {
        objc_getAssociatedObject(bundle, &bundleAssociationKey) as? Bundle
    }
}

extension Bundle {
    @objc fileprivate func mt_overriddenLocalizedString(
        forKey key: String,
        value: String?,
        table: String?
    ) -> String {
        if let override = BundleLanguageOverride.overrideBundle(for: self) {
            // override.mt_overriddenLocalizedString после swizzle = оригинальная реализация.
            return override.mt_overriddenLocalizedString(forKey: key, value: value, table: table)
        }
        // Стандартный путь (после swizzle этот вызов = оригинальная реализация).
        return self.mt_overriddenLocalizedString(forKey: key, value: value, table: table)
    }
}
