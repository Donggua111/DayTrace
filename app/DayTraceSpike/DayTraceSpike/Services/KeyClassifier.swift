import CoreGraphics
import Foundation

/// The only information that leaves keyboard-event classification.
///
/// These cases intentionally have no associated values. A category cannot carry
/// a character, Unicode string, key code, or event sequence.
enum TypingCategory: Equatable {
    case english
    case number
    case symbol
    case space
    case ignored
}

/// Classifies one keyboard event into a privacy-safe aggregate category.
///
/// The event's keyboard output is inspected transiently so that classification
/// follows the active keyboard layout. The temporary value is discarded before
/// the category is returned. IME composition and non-ASCII letters are outside
/// the V1 classifier and return `.ignored`.
enum KeyboardEventClassifier {
    private static let ignoredKeyCodes: Set<Int64> = [
        36,  // Return
        48,  // Tab
        51,  // Delete / Backspace
        53,  // Escape
        54, 55, 56, 57, 58, 59, 60, 61, 62, // modifier keys
        76,  // Keypad Enter
        114, // Help
        115, // Home
        116, // Page Up
        117, // Forward Delete
        118, // End? (legacy keyboard mapping)
        119, // End
        120, // Page Down? (legacy keyboard mapping)
        121, // Page Down
        122, // F1
        123, 124, 125, 126 // Arrow keys
    ]

    private static let symbolCharacters = CharacterSet(charactersIn: ".,!?;:'\"()[]{}<>+-*/=_\\|@#$%^&~`")

    static func classify(event: CGEvent) -> TypingCategory {
        guard event.type == .keyDown else { return .ignored }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard !ignoredKeyCodes.contains(keyCode) else { return .ignored }

        var utf16Buffer = [UniChar](repeating: 0, count: 8)
        var actualLength = 0
        event.keyboardGetUnicodeString(
            maxStringLength: utf16Buffer.count,
            actualStringLength: &actualLength,
            unicodeString: &utf16Buffer
        )

        guard actualLength > 0 else { return .ignored }

        let output = String(utf16CodeUnits: utf16Buffer, count: actualLength)
        guard output.unicodeScalars.count == 1,
              let scalar = output.unicodeScalars.first else {
            return .ignored
        }

        let value = scalar.value
        if value == 0x20 { return .space }
        if (0x41...0x5A).contains(value) || (0x61...0x7A).contains(value) {
            return .english
        }
        if (0x30...0x39).contains(value) {
            return .number
        }
        if value < 0x80, symbolCharacters.contains(scalar) {
            return .symbol
        }

        return .ignored
    }
}

/// Classifier entry point retained under the former file's name.
/// Production event handling uses `KeyboardEventClassifier` directly.
enum KeyClassifier {
    static func classify(event: CGEvent) -> TypingCategory {
        KeyboardEventClassifier.classify(event: event)
    }

    /// Historical keyCode-only behavior retained for the existing spike tests.
    /// It is not used by the production event path and will be removed during
    /// the later metric migration once those historical tests are retired.
    @available(*, deprecated, message: "Use KeyboardEventClassifier.classify(event:) instead")
    static func isQualifying(keyCode: Int64) -> Bool {
        let mainInputKeyCodes = Set(0...51)
        let keypadInputKeyCodes: Set<Int64> = [65, 67, 69, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]
        return mainInputKeyCodes.contains(Int(keyCode)) || keypadInputKeyCodes.contains(keyCode)
    }
}
