import Cocoa
import SwiftUI
import Carbon.HIToolbox

extension AppDelegate {
    func automationState(for id: PlayerID? = nil, prompt: Bool = false) -> AutomationState {
        let pid = id ?? router.activeID
        guard router.source(pid).isRunning else { return .appNotRunning }
        let target = NSAppleEventDescriptor(bundleIdentifier: pid.bundleID)
        guard let desc = target.aeDesc else { return .unknown(0) }
        return AutomationState(osStatus: Int(AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, prompt)))
    }

    func showSetupIfNeeded() {
        if Prefs.setupDone { return }
        if Prefs.hasChosenTarget {
            Prefs.setupDone = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.openSetup() }
    }

    func openSetup() {
        MainActor.assumeIsolated {
            if setupWindow == nil {
                let m = SetupModel()
                m.onOpenSpotify = {
                    if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: PlayerID.spotify.bundleID) {
                        NSWorkspace.shared.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
                m.onAllow = { [weak self] in self?.requestAutomation() }
                m.onOpenSystemSettings = {
                    if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(u)
                    }
                }
                m.onOpenTranslation = { [weak self] in self?.openSettings(tab: "terjemahan") }
                m.onTarget = { [weak self] in self?.langChanged(); self?.refreshSettings() }
                m.onLogin = { [weak self] on in self?.setLogin(on) }
                m.onDone = { [weak self] in self?.finishSetup() }
                setupModel = m
                let hc = NSHostingController(rootView: SetupView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable]
                w.isReleasedWhenClosed = false
                w.setContentSize(NSSize(width: 540, height: 470))
                w.center()
                NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
                    self?.setupClosed()
                }
                setupWindow = w
            }
            setupWindow?.title = L(.setupTitle)
            refreshSetup()
            setupTimer?.invalidate()
            setupTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refreshSetup() }
            NSApp.activate(ignoringOtherApps: true)
            setupWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func refreshSetup() {
        guard setupWindow != nil else { return }
        let running = router.anyRunning
        let auto = automationState(for: router.anyRunning ? (router.active.isRunning ? router.activeID : (router.spotify.isRunning ? .spotify : .music)) : nil)
        let ls = loginState()
        MainActor.assumeIsolated {
            setupModel?.sync(spotify: running, automation: auto, login: ls.on, loginAvailable: ls.available,
                             playerName: (router.active.isRunning ? router.activeID : (router.spotify.isRunning ? .spotify : .music)).displayName)
        }
    }

    func requestAutomation() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.automationState(prompt: true)
            DispatchQueue.main.async { self?.refreshSetup() }
        }
    }

    func finishSetup() {
        setupWindow?.close()
    }

    func setupClosed() {
        setupTimer?.invalidate()
        setupTimer = nil
        Prefs.setupDone = true
        if !Prefs.hasChosenTarget { Prefs.target = Prefs.target }
        langChanged()
        refreshSettings()
    }
}
