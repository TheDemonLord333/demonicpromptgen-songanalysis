import Foundation

/// Schreibt Text in die Zwischenablage. In der App: `SystemPasteboard` (UIPasteboard).
@MainActor
protocol PasteboardWriting: AnyObject {
    func copy(_ text: String)
}

#if canImport(UIKit)
import UIKit

final class SystemPasteboard: PasteboardWriting {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
#endif
