import SwiftUI
import UIKit

/// Не даёт iOS усыпить приложение раньше, чем ядро закончит текущий ход:
/// после сворачивания у нас есть примерно полминуты.
enum BackgroundKeeper {
    private static var task: UIBackgroundTaskIdentifier = .invalid

    static func begin() {
        guard task == .invalid else { return }
        task = UIApplication.shared.beginBackgroundTask(withName: "attach-engine") {
            end()
        }
        Diag.log("app: в фоне, ядру дали время")
    }

    static func end() {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
