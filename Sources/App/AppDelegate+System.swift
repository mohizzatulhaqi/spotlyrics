import Cocoa
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Translation
import NaturalLanguage

extension AppDelegate {
    // An accessory app has no Edit menu, so Cmd+V/C/X/A don't work in text fields.
    // This menu is invisible; it only enables those shortcuts.
    func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let prefs = NSMenuItem(title: L(.settingsMenu), action: #selector(openSettingsAction), keyEquivalent: ",")
        prefs.target = self
        appMenu.addItem(prefs)
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    func playerChoiceChanged() {
        router.reevaluate(now: Date(), activePlaying: false)
        tracker.reset()
        runTick()
    }

    func warnAutomation() {
        guard !shownAutomationAlert else { return }
        shownAutomationAlert = true
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert()
            a.messageText = L(.automationAlertTitle)
            a.informativeText = L(.automationAlertBody)
            a.addButton(withTitle: L(.openSystemSettings))
            a.addButton(withTitle: L(.later))
            if a.runModal() == .alertFirstButtonReturn,
               let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(u)
            }
        }
    }

    var inBundle: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    func setLogin(_ on: Bool) {
        let svc = SMAppService.mainApp
        do {
            if on { try svc.register() } else { try svc.unregister() }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert()
            a.messageText = L(.loginFailed)
            a.informativeText = error.localizedDescription
            a.runModal()
        }
        if svc.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        refreshSettings()
    }

    func loginState() -> (available: Bool, on: Bool, note: String) {
        guard inBundle else { return (false, false, L(.loginNeedsBundle)) }
        let st = SMAppService.mainApp.status
        return (true, st == .enabled, st == .requiresApproval ? L(.loginApprove) : "")
    }
}
