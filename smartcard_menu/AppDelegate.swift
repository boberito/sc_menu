//
//  AppDelegate.swift
//  smartcard_menu
//
//  Created by Gendler, Bob (Fed) on 2/16/24.
//

import Cocoa
import CryptoTokenKit
import SecurityInterface.SFCertificatePanel
import NotificationCenter
import CoreGraphics
import WebKit
import UserNotifications
import os
import ServiceManagement
import Security
import Subprocess
import System

let subsystem = "com.ttinc.sc-menu"

/// Summary of a smartcard's state discovered via APDUs:
/// - `readerName`: Human-readable slot/reader name
/// - `isLocked`: Whether the PIN is locked or requires PIN entry
/// - `hasCerts`: Whether cert objects were found on the card
struct CardStatus {
    var readerName: String = ""
    var isLocked: Bool
    var hasCerts: Bool
}

/// Main application delegate. Manages the menubar item/menu, watches smartcard
/// insertions/removals, posts notifications, and opens auxiliary windows.
///
/// Responsibilities:
/// - Configure login item & first-launch onboarding
/// - Observe screen lock/unlock and sleep/wake to refresh UI
/// - Track token insertion/removal via `TKTokenWatcher`
/// - Build dynamic menus per reader with certificates and debug items
/// - Drive APDU checks to determine lock status and cert presence
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, PrefDataModelDelegate, isLockedDelegate {
    
    func pinFailedandLocked(slotName: String) {
        
        guard let checkCardstatus = checkCard(slotName: slotName) else { return }
        
        if checkCardstatus.isLocked {
            RunLoop.main.perform { [weak self] in
                guard let self else { return }
                if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
                    
                    if let fileURLString = Bundle.main.path(forResource: "smartcard_in_bw", ofType: "png") {
                        
                        guard let buttonImage = NSImage(byReferencingFile: fileURLString) else { return }
                        
                        let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                        if fileExists {
                            if let button = self.statusItem.button {
                                button.image = NSImage(byReferencingFile: fileURLString)
                                let circleSize = NSSize(width: 10, height: 10)
                                let circleOrigin = NSPoint(x: buttonImage.size.width - circleSize.width, y: buttonImage.size.height - circleSize.height)
                                let redCircleImage = NSImage(size: buttonImage.size, flipped: false) { (newImageRect: NSRect) -> Bool in
                                    buttonImage.draw(in: newImageRect)
                                    let circlePath = NSBezierPath(ovalIn: NSRect(origin: circleOrigin, size: circleSize))
                                    NSColor.red.setFill()
                                    circlePath.fill()
                                    return true
                                }
                                guard let _ = redCircleImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                    fatalError("Failed to create CGImage")
                                }
                                button.image = redCircleImage
                            }
                        }
                    } else {
                        guard let fileURLString = Bundle.main.path(forResource: "smartcard_in", ofType: "png") else { return }
                        guard let buttonImage = NSImage(byReferencingFile: fileURLString) else { return }
                        let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                        if fileExists {
                            if let button = self.statusItem.button {
                                button.image = NSImage(byReferencingFile: fileURLString)
                                let circleSize = NSSize(width: 10, height: 10)
                                let circleOrigin = NSPoint(x: buttonImage.size.width - circleSize.width, y: buttonImage.size.height - circleSize.height)
                                let redCircleImage = NSImage(size: buttonImage.size, flipped: false) { (newImageRect: NSRect) -> Bool in
                                    buttonImage.draw(in: newImageRect)
                                    let circlePath = NSBezierPath(ovalIn: NSRect(origin: circleOrigin, size: circleSize))
                                    NSColor.red.setFill()
                                    circlePath.fill()
                                    
                                    return true
                                }
                                guard let _ = redCircleImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                    fatalError("Failed to create CGImage")
                                }
                                button.image = redCircleImage
                            }
                        }
                    }
                }
            }
            guard let statusItemMenu = self.statusItem.menu else { return }
            for menuItem in statusItemMenu.items {
                if menuItem.title == slotName {
                    let lockedMenuItem = NSMenuItem(title: "Smartcard Locked", action: nil, keyEquivalent: "")
                    menuItem.submenu?.insertItem(lockedMenuItem, at: 0)
                    
                }
            }
        }
    }
    func didReceivePrefUpdate() {
        
        var cardStatus = "out"
        if UserDefaults.standard.bool(forKey: "inserted") {
            cardStatus = "in"
        }
        if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
            
            if let fileURLString = Bundle.main.path(forResource: "smartcard_\(cardStatus)_bw", ofType: "png") {
                let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                if fileExists {
                    if let button = self.statusItem.button {
                        button.image = NSImage(byReferencingFile: fileURLString)
                    }
                }
            }
        } else {
            if let fileURLString = Bundle.main.path(forResource: "smartcard_\(cardStatus)", ofType: "png") {
                let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                if fileExists {
                    if let button = self.statusItem.button {
                        button.image = NSImage(byReferencingFile: fileURLString)
                    }
                }
            }
        }
    }
    private let apduLog = OSLog(subsystem: subsystem, category: "APDUFunctions")
    private let prefsLog = OSLog(subsystem: subsystem, category: "Preferences")
    let appLog = OSLog(subsystem: subsystem, category: "General")
    let nc = UNUserNotificationCenter.current()
    let certViewing = ViewCerts()
    var notificationsAllowed = Bool()
    var lockedDictArray = [[String:Bool]]()
    var code: Any?
    var debugMenuItems = [NSMenuItem]()
    var seperatorLines = [NSMenuItem]()
    var exportMenuItems = [NSMenuItem]()
    var myTKWatcher: TKTokenWatcher? = nil
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let nothingInsertedMenu = NSMenuItem(title: "No Smartcard Inserted", action: nil, keyEquivalent: "")
    let iconPref = UserDefaults.standard.string(forKey: "icon_mode") ?? "light"
    var showInsertAfterScreenUnlock = false
    var screenLockedVar = false
    var checkCardStatus: CardStatus?
    
    var runOnMenuItem = [NSMenuItem]()
    
    var menuIsOpen = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // App startup: request notifications, optionally register/unregister as login item,
        // configure observers, and initialize the status item & token watcher.
        UNUserNotificationCenter.current().delegate = self
        os_log("SC Menu launched", log: appLog, type: .default)
        let appService = SMAppService.mainApp
        if CommandLine.arguments.count > 1 {
            
            let arguments = CommandLine.arguments
            
            if arguments[1] == "--register" {
                do {
                    try appService.register()
                    
                    os_log("SC Menu set to launch at login", log: self.prefsLog, type: .default)
                } catch {
                    os_log("SMApp Service register error %{public}s", log: self.prefsLog, type: .error, error.localizedDescription)
                    
                }
            }
            
            if arguments[1] == "--unregister" {
                do {
                    if appService.status == .enabled {
                        try appService.unregister()
                        os_log("SC Menu removed from login items", log: self.prefsLog, type: .default)
                        
                    } else {
                        os_log("SC Menu was not registered to launch", log: self.prefsLog, type: .default)
                    }
                    
                } catch {
                    os_log("Problem unregistering service - error %{public}s", log: self.prefsLog, type: .default, error.localizedDescription)
                }
                
            }
#if !DEBUG
            NSApp.terminate(nil)
#endif
        }
        
        if UserDefaults.standard.bool(forKey: "afterFirstLaunch") == false && appService.status != .enabled {
            
            let alert = NSAlert()
            alert.messageText = "First Launch"
            alert.informativeText = """
        Would you like to allow SC Menu to launch at login?
"""
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                
                do {
                    try appService.register()
                    os_log("registered service", log: self.appLog, type: .default)
                } catch {
                    os_log("problem registering service - error {public}s", log: self.appLog, type: .default, error.localizedDescription)
                }
            }
            
        }
        UserDefaults.standard.setValue(true, forKey: "afterFirstLaunch")
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        let isForced = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
        if UserDefaults.standard.bool(forKey: "disableUpdates") && isForced {
            os_log("Updates disabled", log: self.appLog, type: .default)
        } else {
            let updater = UpdateCheck()
            Task {
                await updater.check()
            }
        }
        
        NSApplication.shared.setActivationPolicy(.accessory)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            switch $0.modifierFlags.intersection(.deviceIndependentFlagsMask) {
            case [.option]:
                for seperatorLine in self.seperatorLines {
                    seperatorLine.isHidden = false
                }
                for runOnMenuItem in self.runOnMenuItem {
                    runOnMenuItem.isHidden = false
                }
                for debugMenuItem in self.debugMenuItems {
                    debugMenuItem.isHidden = false
                }
                for exportMenuItem in self.exportMenuItems {
                    exportMenuItem.isHidden = false
                }
            default:
                for debugMenuItem in self.debugMenuItems {
                    debugMenuItem.isHidden = true
                }
                for exportMenuItem in self.exportMenuItems {
                    exportMenuItem.isHidden = true
                }
                for seperatorLine in self.seperatorLines {
                    seperatorLine.isHidden = true
                }
                for runOnMenuItem in self.runOnMenuItem {
                    runOnMenuItem.isHidden = true
                }
                
            }
        }
        
        notificationPermissions()
        startup()
    }
    
    /// Request local notification permissions and seed the `show_notifications` default
    /// if the user didn't previously choose.
    func notificationPermissions() {
        nc.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                if UserDefaults.standard.value(forKey: "show_notifications") == nil {
                    UserDefaults.standard.set(true, forKey: "show_notifications")
                }
                os_log("Notifications allowed", log: self.appLog, type: .default)
            } else {
                UserDefaults.standard.set(false, forKey: "show_notifications")
                os_log("Notifications denied", log: self.appLog, type: .default)
            }
        }
        
    }
    
    /// When the screen unlocks, refresh menu state and optionally show the insert notification once.
    @objc func screenUnlocked() {
        showInsertAfterScreenUnlock = true
        screenLockedVar = false
        startup()
    }
    
    @objc func screenLocked() {
        screenLockedVar = true
    }
    
    func insertExistingTokens(){
        
        guard let tokenIDs = myTKWatcher?.tokenIDs else {
            return
        }
        for token in tokenIDs {
            self.showReader(TkID: token)
        }
        
    }
    /// Reset the status bar menu/icon to the default (no card), create the token watcher,
    /// and set up insertion handling. Also adds the Quit/Preferences items.
    func startup() {
        myTKWatcher = TKTokenWatcher.init()
        statusItem.menu = NSMenu()
        statusItem.menu?.insertItem(nothingInsertedMenu, at: 0)
        statusItem.menu?.delegate = self
        UserDefaults.standard.setValue(false, forKey: "inserted")
        if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
            if let fileURLString = Bundle.main.path(forResource: "smartcard_out_bw", ofType: "png") {
                let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                if fileExists {
                    if let button = self.statusItem.button {
                        button.image = NSImage(byReferencingFile: fileURLString)
                    }
                } else {
                    self.statusItem.button?.title = "NOT Inserted"
                }
            }
        } else {
            if let fileURLString = Bundle.main.path(forResource: "smartcard_out", ofType: "png") {
                let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                if fileExists {
                    if let button = self.statusItem.button {
                        button.image = NSImage(byReferencingFile: fileURLString)
                    }
                } else {
                    self.statusItem.button?.title = "NOT Inserted"
                }
            }
        }
        
        myTKWatcher?.setInsertionHandler({ [weak self] tokenID in
            guard let self = self else { return }
            self.update(CTKTokenID: tokenID)
        })
        addQuit()
    }
    /// On wake, close stray windows, rebuild the menu, and re-run startup to refresh state.
    @objc private func sleepListener(_ aNotification: Notification) {
        
        if aNotification.name == NSWorkspace.didWakeNotification {
            for currentWindow in NSApplication.shared.windows {
                if String(describing: type(of: currentWindow)) == "NSStatusBarWindow" {
                    continue
                } else {
                    currentWindow.close()
                }
            }
            if let menuItems = statusItem.menu {
                for item in menuItems.items {
                    statusItem.menu?.removeItem(item)
                }
            }
            showInsertAfterScreenUnlock = true
            startup()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    /// Open the Preferences window (or focus it if already open) and assign the delegate
    /// so icon changes or other prefs propagate to the status bar.
    @objc func preferencesWindow(_ sender: NSMenuItem) {
        
        for currentWindow in NSApplication.shared.windows {
            if currentWindow.title.contains("SC Menu Preferences") {
                NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
        }
        var window: PreferencesWindow?
        let windowSize = NSSize(width: 415, height: 200)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        window = PreferencesWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .titled], backing: .buffered, defer: false)
        window?.title = "SC Menu Preferences"
        let freshPrefViewController = PreferencesViewController()
        
        window?.contentViewController = freshPrefViewController
        
        freshPrefViewController.delegate = self
        
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        
        
    }
    /// Open a web window to smartcard-atr.apdu.fr with the card's ATR for debugging purposes.
    @objc func ATRfunc(_ sender: NSMenuItem) {
        os_log("Debug selected. Thanks Ludovic https://smartcard-atr.apdu.fr", log: appLog, type: .default)
        let token = sender.representedObject as! String
        if let slotName = myTKWatcher?.tokenInfo(forTokenID: token)?.slotName, let driverName = myTKWatcher?.tokenInfo(forTokenID: token)?.driverName {
            let pivCard = PIVCard(token: token, slotName: slotName, driverName: driverName)
            var window: WebWindow!
            let _wndW : CGFloat = 800
            let _wndH : CGFloat = 800
            window = WebWindow(contentRect:NSMakeRect(0,0,_wndW,_wndH),styleMask:[.titled, .closable], backing:.buffered, defer:false)
            let webView = WKWebView()
            webView.wantsLayer = true
            guard let atrString = pivCard.atrString else { return }
            let debugURL = "https://smartcard-atr.apdu.fr/parse?ATR=\(atrString)"
            webView.load(URLRequest(url: URL(string: debugURL)!))
            
            window.contentView = webView
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            
        }
        
    }
    /// Convert DER-encoded data to PEM string with appropriate BEGIN/END headers.
    /// `PEMType` controls whether CERTIFICATE or CERTIFICATE REQUEST headers are used.
    func PEMKeyFromDERKey(_ data: Data, PEMType: String) -> String {
        let kCryptoExportImportManagerPublicKeyInitialTag = "-----BEGIN CERTIFICATE-----\n"
        let kCryptoExportImportManagerPublicKeyFinalTag = "-----END CERTIFICATE-----\n"
        
        let kCryptoExportImportManagerRequestInitialTag = "-----BEGIN CERTIFICATE REQUEST-----\n"
        let kCryptoExportImportManagerRequestFinalTag = "-----END CERTIFICATE REQUEST-----\n"
        
        let kCryptoExportImportManagerPublicNumberOfCharactersInALine = 64
        
        var resultString: String
        
        // base64 encode the result
        let base64EncodedString = data.base64EncodedString(options: [])
        
        // split in lines of 64 characters.
        var currentLine = ""
        if PEMType == "RSA" {
            resultString = kCryptoExportImportManagerPublicKeyInitialTag
        } else {
            resultString = kCryptoExportImportManagerRequestInitialTag
        }
        var charCount = 0
        for character in base64EncodedString {
            charCount += 1
            currentLine.append(character)
            if charCount == kCryptoExportImportManagerPublicNumberOfCharactersInALine {
                resultString += currentLine + "\n"
                charCount = 0
                currentLine = ""
            }
        }
        // final line (if any)
        if currentLine.count > 0 { resultString += currentLine + "\n" }
        // final tag
        if PEMType == "RSA" {
            resultString += kCryptoExportImportManagerPublicKeyFinalTag
        } else {
            resultString += kCryptoExportImportManagerRequestFinalTag
        }
        return resultString
    }
    
    /// Present a save panel to export a selected identity's certificate as PEM or DER.
    /// Uses Security framework APIs to extract the public certificate from a `SecIdentity`.
    @objc func exportCerts(_ sender: NSMenuItem) {
        os_log("Export certificates selected", log: appLog, type: .default)
        let pivToken = sender.representedObject as! String
        var pemcerts = [String:String]()
        guard let certDict = certViewing.getIdentity(pivToken: pivToken) else { return }
        for (k,v) in certDict {
            var pem : String? = nil
            
            var publicCert: SecCertificate? = nil
            //
            let err = SecIdentityCopyCertificate(v, &publicCert)
            //
            if err == 0 {
                let certData = SecCertificateCopyData(publicCert!)
                pem = PEMKeyFromDERKey(certData as Data, PEMType: "RSA")
            } else {
                os_log("Error getting public certificates", log: appLog, type: .default)
                return
            }
            if let pem = pem {
                pemcerts.updateValue(pem, forKey: k)
            }
            
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save a certificate file."
        savePanel.message = "Choose where to save your certificate file:"
        savePanel.prompt = "Save Certificate"
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.x509Certificate]
        savePanel.allowsOtherFileTypes = true
        let certsPopup = NSPopUpButton(frame: NSRect(x: 135, y: 30, width: 350, height: 25), pullsDown: false)
        let sortedDictKeys = pemcerts.sorted(by: { $0.key < $1.key }).map(\.key)
        certsPopup.addItems(withTitles: sortedDictKeys)
        let formatPopup = NSPopUpButton(frame: NSRect(x: 135, y: 0, width: 100, height: 25), pullsDown: false)
        formatPopup.addItems(withTitles: ["PEM", "DER"])
        let formatPopupLabel = NSTextField(frame: NSRect(x: 10, y: 0, width: 100, height: 25))
        formatPopupLabel.stringValue = "Select Format: "
        formatPopupLabel.isBordered = false
        formatPopupLabel.isBezeled = false
        let certsPopUpLabel = NSTextField(frame: NSRect(x: 10, y: 28, width: 125, height:25))
        certsPopUpLabel.stringValue = "Select a Certificate: "
        certsPopUpLabel.isBordered = false
        certsPopUpLabel.isBezeled = false
        let accessoryView = NSView()
        accessoryView.frame = NSRect(x:0, y:0, width: 500, height: 75)
        accessoryView.translatesAutoresizingMaskIntoConstraints = true
        accessoryView.addSubview(formatPopupLabel)
        accessoryView.addSubview(certsPopup)
        accessoryView.addSubview(formatPopup)
        accessoryView.addSubview(certsPopUpLabel)
        savePanel.accessoryView = accessoryView
        savePanel.begin(completionHandler: { response in
            
            if response.rawValue != 0 {
                
                do {
                    guard let selectedCert = certsPopup.selectedItem?.title else { return }
                    
                    if formatPopup.selectedItem?.title == "DER" {
                        var publicCert: SecCertificate? = nil
                        let err = SecIdentityCopyCertificate(certDict[selectedCert]!, &publicCert)
                        if err == 0 {
                            let certData = SecCertificateCopyData(publicCert!) as Data
                            try certData.write(to: savePanel.url!)
                        }
                        
                    } else {
                        guard let pemcert = pemcerts[selectedCert] else { return }
                        try pemcert.write(to: savePanel.url!, atomically: true, encoding: String.Encoding.utf8)
                    }
                } catch {
                    os_log("{public}s", log: self.appLog, type: .error, error.localizedDescription)
                    return
                }
            }
        })
        savePanel.makeKeyAndOrderFront(nil)
        savePanel.orderFrontRegardless()
        
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
    }
    
    /// Open a certificate details window (SFCertificateView) for the selected identity.
    /// If a window for that cert is already open, bring it to front instead.
    @objc func certSelected(_ sender: NSMenuItem) {
        
        for currentWindow in NSApplication.shared.windows {
            if currentWindow.title.contains(sender.title) {
                NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
        }
        var window: CertWindow?
        let _wndW: CGFloat = 500
        let _wndH: CGFloat = 500
        
        window = CertWindow(contentRect:NSMakeRect(0,0,_wndW,_wndH),styleMask:[.titled, .closable, .resizable], backing:.buffered, defer:false)
        
        window?.title = sender.title
        window?.center()
        let viewCertsViewController = ViewCertsViewController()
        viewCertsViewController.selectedCert = (sender.representedObject as! SecIdentity)
        window?.contentViewController = viewCertsViewController
        
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        
    }
    
    
    /// Ensure a reader submenu exists for the provided token ID, populate it with
    /// certificates (if available), and add debug/export items. Also reflects lock state.
    func showReader(TkID: String) {
        
        func insert() {
            let readerName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName ?? TkID
            //Escapes and doesn't show the token for the Secure Enclave or pSSO registration.
            if TkID.contains("com.apple.setoken") || TkID.contains("com.apple.ctkcard") { return }
            if let pivToken = myTKWatcher?.tokenInfo(forTokenID: TkID)?.tokenID {
                let readerMenuItem = NSMenuItem(title: readerName, action: nil, keyEquivalent: "")
                readerMenuItem.representedObject = TkID
                let readerMenuItemExists = statusItem.menu?.item(withTitle: readerName)
                if readerMenuItemExists == nil {
                    let subMenu = NSMenu()
                    if statusItem.menu?.index(of: nothingInsertedMenu) != -1 {
                        UserDefaults.standard.setValue(true, forKey: "inserted")
                        statusItem.menu?.removeItem(nothingInsertedMenu)
                    }
                    
                    if certViewing.getIdentity(pivToken: pivToken) == nil{
                        guard let checkCardStatus = checkCardStatus else {
                            return
                            
                        }
                        if checkCardStatus.hasCerts {
                            statusItem.menu?.insertItem(readerMenuItem, at: 0)
                            statusItem.menu?.setSubmenu(subMenu, for:  readerMenuItem)
                            if statusItem.menu?.item(withTitle: "Keychain Locked Error Reading Smartcards") == nil {
                                let keychainLockedItem = NSMenuItem(title: "Keychain Locked Error Reading Smartcards", action: nil, keyEquivalent: "")
                                for dict in self.lockedDictArray {
                                    if dict[TkID] == true {
                                        if subMenu.item(withTitle: "Smartcard Locked") == nil {
                                            let lockedMenuItem = NSMenuItem(title: "Smartcard Locked", action: nil, keyEquivalent: "")
                                            subMenu.addItem(lockedMenuItem)
                                            os_log("%{public}s is locked", log: appLog, type: .default, TkID.description)
                                        }
                                    }
                                }
                                subMenu.addItem(keychainLockedItem)
                                addQuit()
                            }
                            return
                            
                            
                        } else {
                            statusItem.menu?.insertItem(readerMenuItem, at: 0)
                            statusItem.menu?.setSubmenu(subMenu, for:  readerMenuItem)
                            if subMenu.item(withTitle: "No Certificates Found on Smartcard") == nil {
                                let noCertMenuItem = NSMenuItem(title: "No Certificates Found on Smartcard", action: nil, keyEquivalent: "")
                                for dict in self.lockedDictArray {
                                    if dict[TkID] == true {
                                        if subMenu.item(withTitle: "Smartcard Locked") == nil {
                                            let lockedMenuItem = NSMenuItem(title: "Smartcard Locked", action: nil, keyEquivalent: "")
                                            subMenu.addItem(lockedMenuItem)
                                            os_log("%{public}s is locked", log: appLog, type: .default, TkID.description)
                                        }
                                    }
                                }
                                subMenu.addItem(noCertMenuItem)
                                addQuit()
                                
                            }
                            return
                        }
                        
                    }
                    
                    statusItem.menu?.insertItem(readerMenuItem, at: 0)
                    statusItem.menu?.setSubmenu(subMenu, for:  readerMenuItem)
                    if let certDict = certViewing.getIdentity(pivToken: pivToken){
                        for dict in self.lockedDictArray {
                            if dict[TkID] == true {
                                if subMenu.item(withTitle: "Smartcard Locked") == nil {
                                    let lockedMenuItem = NSMenuItem(title: "Smartcard Locked", action: nil, keyEquivalent: "")
                                    subMenu.addItem(lockedMenuItem)
                                    os_log("%{public}s is locked", log: appLog, type: .default, TkID.description)
                                }
                            }
                        }
                        var seperator = false
                        let sortedDictKeys = certDict.sorted(by: { $0.key < $1.key }).map(\.key)
                        for key in sortedDictKeys {
                            if key.contains("Retired") && !seperator {
                                subMenu.addItem(NSMenuItem.separator())
                                seperator = true
                            }
                            
                            let label = NSMenuItem(title: key, action: #selector(certSelected), keyEquivalent: "")
                            label.representedObject = certDict[key]
                            subMenu.addItem(label)
                        }
                        
                        let seperatorLine = NSMenuItem.separator()
                        let myCardInfo = NSMenuItem(title: "Additional Card Info", action: #selector(cardInfo), keyEquivalent: "")
                        myCardInfo.representedObject = readerName
                        subMenu.addItem(seperatorLine)
                        subMenu.addItem(myCardInfo)
                        
                        let hiddenSeperatorLine = NSMenuItem.separator()
                        hiddenSeperatorLine.isHidden = true
                        seperatorLines.append(hiddenSeperatorLine)
                        subMenu.addItem(hiddenSeperatorLine)
                        let exportMenuItem = NSMenuItem(title: "Export Certificates", action: #selector(exportCerts), keyEquivalent: "")
                        exportMenuItem.representedObject = TkID
                        exportMenuItem.isHidden = true
                        exportMenuItems.append(exportMenuItem)
                        subMenu.addItem(exportMenuItem)
                        let debugItem = NSMenuItem(title: "Debug Info", action: #selector(ATRfunc), keyEquivalent: "")
                        debugItem.representedObject = TkID
                        debugItem.isHidden = true
                        debugMenuItems.append(debugItem)
                        subMenu.addItem(debugItem)
                    }
                    addQuit()
                } else {
                    return;
                }
                
            }
        }
        //if menu is NOT open, insert the things
        //if menu is open, dispatch queue it and insert
        if !menuIsOpen {
            insert()
        } else {
            DispatchQueue.main.async {
                insert()
            }
        }
        
        
        
    }
    /// Prompt for PIN and open the "Additional Card Information" window which performs
    /// APDU reads (via `MyInfoViewController`) to display PIV data and CHUID fields.
    @objc func cardInfo(_ sender: NSMenuItem) {
        
        let cardReader = sender.representedObject as! String
        for currentWindow in NSApplication.shared.windows {
            //                if currentWindow.title.contains("Additonal Card Information") {
            let identifier = cardReader
            if currentWindow.identifier == NSUserInterfaceItemIdentifier(cardReader) {
                
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue ==  identifier }) {
                    window.makeKeyAndOrderFront(nil)
                }
                return
            }
        }
        let accessoryView = NSView()
        accessoryView.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout
        
        let textLabel = NSTextField(labelWithString: "Enter PIN.")
        textLabel.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout
        textLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        
        let secureTextInput = NSSecureTextField()
        secureTextInput.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout
        
        // Add subviews to the accessory view
        accessoryView.addSubview(textLabel)
        accessoryView.addSubview(secureTextInput)
        
        // Add constraints to the subviews
        NSLayoutConstraint.activate([
            // Accessory text view constraints
            textLabel.topAnchor.constraint(equalTo: accessoryView.topAnchor, constant: 10),
            textLabel.leadingAnchor.constraint(equalTo: accessoryView.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: accessoryView.trailingAnchor),
            
            // Secure text input constraints
            secureTextInput.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 10),
            secureTextInput.leadingAnchor.constraint(equalTo: accessoryView.leadingAnchor),
            secureTextInput.trailingAnchor.constraint(equalTo: accessoryView.trailingAnchor),
            secureTextInput.heightAnchor.constraint(equalToConstant: 25),
            
            // Accessory view bottom constraint
            secureTextInput.bottomAnchor.constraint(equalTo: accessoryView.bottomAnchor, constant: -10),
            
            // Accessory view width constraint
            accessoryView.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        let alert = NSAlert()
        alert.messageText = "SC Menu"
        //        alert.informativeText = "Informative text."
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // Force layout update before displaying the alert
        accessoryView.layoutSubtreeIfNeeded()
        
        // Run the alert and handle button response
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            guard let pin = secureTextInput.stringValue.data(using: .utf8) else {
                os_log("Invalid PIN format.", log: appLog, type: .default)
                return
            }
            let myInfoViewController = MyInfoViewController()
            myInfoViewController.pinDelegate = self
            myInfoViewController.pin = pin
            myInfoViewController.passedSlot = cardReader
            os_log("SC Menu is opening my card info.", log: appLog, type: .default)
            
            var window: MyInfoWindow?
            let windowSize = NSSize(width: 415, height: 200)
            let screenSize = NSScreen.main?.frame.size ?? .zero
            let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
            window = MyInfoWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .titled], backing: .buffered, defer: false)
            window?.title = "Additonal Card Information"
            window?.identifier = NSUserInterfaceItemIdentifier(cardReader)
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
            window?.contentViewController = myInfoViewController
            
            
        } else if response == .alertSecondButtonReturn {
            os_log("Cancel button pressed", log: appLog, type: .default)
            return
        }
        
    }
    
    @objc func quit() {
        os_log("SC Menu is quitting.", log: appLog, type: .default)
        exit(0)
    }
    
    /// Append Preferences and Quit items to the bottom of the status menu (if not present),
    /// and restore a placeholder when no card is inserted.
    func addQuit() {
        
        if statusItem.menu?.indexOfItem(withTitle: "Quit") == -1 {
            statusItem.menu?.addItem(NSMenuItem.separator())
            if statusItem.menu?.indexOfItem(withTitle: "Preferences") == -1 {
                let prefMenu = NSMenuItem(title: "Preferences", action: #selector(preferencesWindow), keyEquivalent: "")
                statusItem.menu?.addItem(prefMenu)
            }
            let quitMenu = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
            statusItem.menu?.addItem(quitMenu)
        }
        
        if statusItem.menu?.indexOfItem(withTitle: "Quit") == 2 {
            statusItem.menu?.insertItem(self.nothingInsertedMenu, at: 0)
            UserDefaults.standard.setValue(false, forKey: "inserted")
        }
        
    }
    
    /// Update the status bar icon to the provided asset, overlaying a red dot if any
    /// currently tracked token is locked.
    func menuBarIcon(fileURLString: String) {
        RunLoop.main.perform { [ weak self ] in
            guard let self else { return }
            let fileExists = FileManager.default.fileExists(atPath: fileURLString)
            if fileExists {
                if let button = self.statusItem.button {
                    
                    for dict in self.lockedDictArray {
                        
                        if dict.values.contains(true) {
                            if let buttonImage = NSImage(byReferencingFile: fileURLString){
                                
                                let circleSize = NSSize(width: 10, height: 10)
                                let circleOrigin = NSPoint(x: buttonImage.size.width - circleSize.width, y: buttonImage.size.height - circleSize.height)
                                let redCircleImage = NSImage(size: buttonImage.size, flipped: false) { (newImageRect: NSRect) -> Bool in
                                    buttonImage.draw(in: newImageRect)
                                    let circlePath = NSBezierPath(ovalIn: NSRect(origin: circleOrigin, size: circleSize))
                                    NSColor.red.setFill()
                                    circlePath.fill()
                                    
                                    return true
                                }
                                
                                guard let _ = redCircleImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                    fatalError("Failed to create CGImage")
                                }
                                button.image = redCircleImage
                                
                            }
                            break
                        } else {
                            button.image = NSImage(byReferencingFile: fileURLString)
                        }
                        
                    }
                    
                }
            } else {
                self.statusItem.button?.title = "Inserted"
            }
            
        }
    }
    //script to run script on insert or removal
    func run_on(action: String, path: String) async {
        let pathURL = URL(fileURLWithPath: path)
        let ext = pathURL.pathExtension
        var typeOfScript: String?
        var typeOfFile: String?
        //check file type using subprocess to run the file command
        
        let typeCheck = try? await run(
            .path("/bin/bash"),
            arguments: ["-c", "/usr/bin/file -b --mime-type \(path) | /usr/bin/head -1 | /usr/bin/cut -d/ -f1"],
            output: .string(limit: 4096, encoding: UTF8.self)
        )
        typeOfFile = String(describing: typeCheck?.standardOutput ?? "")
        typeOfFile = typeOfFile?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        //if it's a text file check to see if it has a shebang
        //if no shebang, determine script type
        if typeOfFile == "text" {
            if let scriptContents = try? String(contentsOf: pathURL) {
                if !"#!/".contains(scriptContents.components(separatedBy: "\n")[0]) {
                    if "py".contains(ext) {
                        typeOfScript = "python"
                    }
                    if ["sh","zsh","bash"].contains(ext) {
                        typeOfScript = "shell"
                    }
                }
            }
        }
        //if binary or has a shebang, just run it
        if typeOfScript == nil {
            do {
                let result = try await run(
                    .path(FilePath(path)),
                    output: .string(limit: 4096, encoding: UTF8.self),
                    error: .string(limit: 4096, encoding: UTF8.self)
                )
                
                os_log("%{public}s Script Exit Code %{public}s", log: appLog, type: .default, action, String(describing: result.terminationStatus))
                os_log("%{public}s Script Output %{public}s", log: appLog, type: .debug, action, result.standardOutput ?? "")
                os_log("%{public}s Script Stderr %{public}s", log: appLog, type: .debug, action, result.standardError ?? "")
            } catch {
                os_log("%{public}s", log: appLog, type: .error, error.localizedDescription)
            }
            //if text and has no shebang
            //find environment python3 if python
            //find the default user shell and run with that otherwise
        } else {
            var shell: String?
            if typeOfScript == "python" {
                shell = "/usr/bin/env python3"
            } else if typeOfScript == "shell" {
                shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            }
            do {
                guard let shell else { return }
                
                let result = try await run(
                    .path(FilePath(shell)),
                    arguments: [path],
                    output: .string(limit: 4096, encoding: UTF8.self),
                    error: .string(limit: 4096, encoding: UTF8.self)
                )
                
                os_log("%{public}s Script Exit Code %{public}s", log: appLog, type: .default, action, String(describing: result.terminationStatus))
                os_log("%{public}s Script Output %{public}s", log: appLog, type: .debug, action, result.standardOutput ?? "")
                os_log("%{public}s Script Stderr %{public}s", log: appLog, type: .debug, action, result.standardError ?? "")
            } catch {
                os_log("%{public}s", log: appLog, type: .error, error.localizedDescription)
            }
            
        }
    }
    /// Handle a token insertion: optional script execution, lock/cert checks, notification,
    /// expiration scan, and UI/menu updates. Also registers a paired removal handler.
    func update(CTKTokenID: String) {
        if myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName != nil {
            os_log("Smartcard Inserted %{public}s", log: appLog, type: .default, CTKTokenID.description)
            checkCardStatus = checkCard(slotName: myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName)
            if UserDefaults.standard.bool(forKey: "run_on_insert") {
                if let scriptPath = UserDefaults.standard.string(forKey: "run_on_insert_script_path") {
                    Task {
                        await run_on(action: "Insert", path: scriptPath)
                    }
                }
            }
            guard let isCardLocked = checkCardStatus?.isLocked else { return }
            lockedDictArray.append([CTKTokenID:isCardLocked])
            
            if UserDefaults.standard.bool(forKey: "show_notifications") {
                if showInsertAfterScreenUnlock == false && screenLockedVar == false {
                    Task {
                        let settings = await nc.notificationSettings()
                        guard (settings.authorizationStatus == .authorized) ||
                                (settings.authorizationStatus == .provisional) else
                        { return }
                        let content = UNMutableNotificationContent()
                        content.title = "SC Menu"
                        content.body = "Smartcard Inserted"
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        try await nc.add(request)
                    }
                }
            }
            if let pivToken = myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.tokenID {
                Task { [weak self] in
                    guard let self else { return }
                    await certViewing.readExpiration(pivToken: pivToken)
                }
                
            }
            showInsertAfterScreenUnlock = false
            if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
                if let fileURLString = Bundle.main.path(forResource: "smartcard_in_bw", ofType: "png") {
                    menuBarIcon(fileURLString: fileURLString)
                    self.showReader(TkID: CTKTokenID)
                }
            } else {
                if let fileURLString = Bundle.main.path(forResource: "smartcard_in", ofType: "png") {
                    menuBarIcon(fileURLString: fileURLString)
                    self.showReader(TkID: CTKTokenID)
                    
                }
            }
        }
        
        myTKWatcher?.addRemovalHandler({ [weak self] CTKTokenID in
            guard let self = self else { return }
            func remove() {
                for scMenuItem in self.statusItem.menu!.items {
                    if scMenuItem.title == "Keychain Locked Error Reading Smartcards" {
                        self.statusItem.menu?.removeItem(scMenuItem)
                    }
                    if let scMenuItemRepresentedObj = scMenuItem.representedObject as? String {
                        if scMenuItemRepresentedObj == CTKTokenID {
                            self.statusItem.menu?.removeItem(scMenuItem)
                        }
                    }
                    self.addQuit()
                }
                
                if self.statusItem.menu?.item(withTitle: "No Smartcard Inserted") != nil {
                    if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
                        
                        if let fileURLString = Bundle.main.path(forResource: "smartcard_out_bw", ofType: "png") {
                            let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                            if fileExists {
                                
                                if let button = self.statusItem.button {
                                    DispatchQueue.main.async {
                                        button.image = NSImage(byReferencingFile: fileURLString)
                                    }
                                    
                                }
                            } else {
                                self.statusItem.button?.title = "NOT Inserted"
                            }
                        }
                    } else {
                        if let fileURLString = Bundle.main.path(forResource: "smartcard_out", ofType: "png") {
                            let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                            if fileExists {
                                if let button = self.statusItem.button {
                                    DispatchQueue.main.async {
                                        button.image = NSImage(byReferencingFile: fileURLString)
                                    }
                                }
                            } else {
                                self.statusItem.button?.title = "NOT Inserted"
                            }
                        }
                    }
                }
                self.debugMenuItems.removeAll(where: { $0.menu == nil })
                self.exportMenuItems.removeAll(where: { $0.menu == nil })
                self.seperatorLines.removeAll(where: { $0.menu == nil })
            }
            
            os_log("Smartcard Removed %{public}s", log: self.appLog, type: .default, CTKTokenID.description)
            if UserDefaults.standard.bool(forKey: "run_on_removal") {
                if let scriptPath = UserDefaults.standard.string(forKey: "run_on_removal_script_path") {
                    
                    Task {
                        await self.run_on(action: "Removal", path: scriptPath)
                    }
                }
                
                
            }
            self.checkCardStatus = nil
            if let index = self.lockedDictArray.firstIndex(where: { $0.keys.contains(CTKTokenID) }) {
                if UserDefaults.standard.bool(forKey: "show_notifications") {
                    if !self.screenLockedVar {
                        Task {
                            let settings = await self.nc.notificationSettings()
                            guard (settings.authorizationStatus == .authorized) ||
                                    (settings.authorizationStatus == .provisional) else
                            { return }
                            let content = UNMutableNotificationContent()
                            content.title = "SC Menu"
                            content.body = "Smartcard Removed"
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                            
                            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                            try await self.nc.add(request)
                            
                        }
                    }
                }
                self.lockedDictArray.remove(at: index)
                if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
                    if let fileURLString = Bundle.main.path(forResource: "smartcard_in_bw", ofType: "png") {
                        self.menuBarIcon(fileURLString: fileURLString)
                    }
                } else {
                    if let fileURLString = Bundle.main.path(forResource: "smartcard_in", ofType: "png") {
                        self.menuBarIcon(fileURLString: fileURLString)
                        
                    }
                }
                
            }
            //if menu is NOT open, remove the things
            //if menu is open, dispatch queue it and remove
            if !self.menuIsOpen {
                remove()
            } else {
                DispatchQueue.main.async {
                    remove()
                }
            }
        }, forTokenID: CTKTokenID)
    }
    /// Perform low-level APDU exchanges against the card in the provided slot to determine
    /// lock status and whether certificate objects exist. Returns a `CardStatus` snapshot.
    ///
    /// Note: Uses a semaphore to serialize the async TKSmartCard calls for a synchronous return.
    func checkCard(slotName: String?) -> (CardStatus?) {
        // This routine synchronously probes the card using APDUs to determine two things:
        // 1) Is the PIN currently locked (or requires PIN)?
        // 2) Do PIV certificate data objects (9A/9C/9D/9E) exist on the card?
        //
        // It uses a semaphore to block until all asynchronous CryptoTokenKit calls complete.
        
        let sm = TKSmartCardSlotManager()
        var card : TKSmartCard? = nil
        // Use a semaphore to convert the async TKSmartCard flow into a synchronous return value.
        let sema = DispatchSemaphore.init(value: 0)
        
        guard let slotName = slotName else { return nil }
        sm.getSlot(withName: slotName, reply: { currentslot in
            card = currentslot?.makeSmartCard()
            guard card != nil else {
                card?.endSession()
                sema.signal()
                return
            }
            sema.signal()
        })
        sema.wait()
        
        var hasCerts = false
        var locked = false
        
        
        func sendAPDU(apdu: [UInt8], completion: (Data, Error)) {
            let apduData = Data(apdu)
            card?.transmit(apduData, reply: { data, error in
                
            })
        }
        
        
        card?.beginSession(reply: { something, error in
            // APDUs used in this check:
            // - SELECT (AID) to select the PIV application
            // - VERIFY PIN with LC=0 ("null verify") to read remaining attempts (and infer locked state)
            // - GET DATA for PIV cert containers 9A/9C/9D/9E to infer if certs exist
            
            let apid : [UInt8] = [0x00, 0xa4, 0x04, 0x00, 0x0b, 0xa0, 0x00, 0x00, 0x03, 0x08, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00 ]
            let pinVerifyNull : [UInt8] = [ 0x00, 0x20, 0x00, 0x80, 0x00]
            let getCert9A: [UInt8] = [ 0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x05, 0x00 ]
            let getCert9C: [UInt8] = [ 0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x0A, 0x00 ]
            let getCert9D: [UInt8] = [ 0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x0B, 0x00 ]
            let getCert9E: [UInt8] = [ 0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x01, 0x00 ]
            let apidRequest = Data(apid)
            let request2 = Data(pinVerifyNull)
            
            
            // Helper that sends an APDU and follows up with GET RESPONSE (00 C0 00 00 Le) if SW1==0x61
            // to retrieve remaining bytes, concatenating all chunks before calling completion.
            func sendMoreAPDUCommands(apdu: [UInt8], completion: @escaping ([UInt8], UInt8, UInt8) -> Void) {
                
                // Convert command array to Data
                let apduData = Data(apdu)
                
                if let smartCard = card {
                    smartCard.transmit(apduData) { response, error in
                        guard let responseData = response, error == nil else {
                            completion([], 0x00, 0x00)
                            return
                        }
                        if error != nil {
                            card?.endSession()
                            sema.signal()
                            return
                        }
                        
                        
                        var responseBytes = Array(responseData.dropLast(2)) // Extract response without SW1, SW2
                        // SW1/SW2 are the last two bytes of the response (status words). Drop them from the payload.
                        let sw1 = responseData[responseData.count - 2]
                        let sw2 = responseData[responseData.count - 1]
                        
                        // Check if more data is available (SW1 == 0x61)
                        if sw1 == 0x61 {
                            // 0x61 indicates more data is available; issue GET RESPONSE for the indicated length (SW2)
                            let getResponseCommand: [UInt8] = [
                                0x00, 0xC0, 0x00, 0x00, sw2
                            ]
                            
                            // Call sendAPDUCommand recursively to get the remaining data
                            sendMoreAPDUCommands(apdu: getResponseCommand) { moreData, moreSW1, moreSW2 in
                                responseBytes += moreData // Combine the previously received data with the new data
                                
                                // Check the final SW1 and SW2
                                if moreSW1 == 0x90 && moreSW2 == 0x00 {
                                    // Handle successful retrieval of all data
                                    completion(responseBytes, moreSW1, moreSW2)
                                } else {
                                    // Return the status words and received data
                                    completion(responseBytes, moreSW1, moreSW2)
                                }
                            }
                        } else {
                            // No more data, return the response and status words
                            completion(responseBytes, sw1, sw2)
                        }
                    }
                } else {
                    completion([], 0, 0)
                }
            }
            
            
            card?.transmit(apidRequest, reply: { data, error in
                if error == nil {
                    
                    // Null VERIFY (LC=0) doesn't change PIN state but returns remaining attempts in SW1/SW2.
                    // We use it to infer `locked` without requiring the user's PIN.
                    card?.transmit(request2, reply: { data, error in
                        guard let data = data else { return }
                        let result = data.hexEncodedString()
                        
                        // SW1/SW2 as hex string. "63Cx" means verify failed with x attempts remaining.
                        // "9000" means success; any other code is treated as locked for safety.
                        if result.starts(with: "63c") {
                            if let attempts = Int(String(result.last!), radix: 16) {
                                if attempts == 0 {
                                    locked = true
                                } else {
                                    locked = false
                                }
                            }
                        } else if result == "9000" {
                            locked = false
                        } else {
                            locked = true
                        }
                        
                    })
                    // Probe for presence of PIV certificate data objects. If any container returns payload
                    // (bytes > 2), assume certs are present on the card.
                    sendMoreAPDUCommands(apdu: getCert9A) { data, sw1, sw2 in
                        // 9A: PIV Authentication cert
                        if sw1 == 0x90 && sw2 == 0x00 {
                            os_log("9A bytes received: %{public}s", log: self.apduLog, type: .debug, "\(data.count)")
                            if data.count > 2 {
                                hasCerts = true
                            }
                        }
                        sendMoreAPDUCommands(apdu: getCert9C) { data, sw1, sw2 in
                            // 9C: Digital Signature cert
                            if sw1 == 0x90 && sw2 == 0x00 {
                                os_log("9C bytes received: %{public}s", log: self.apduLog, type: .debug, "\(data.count)")
                                if data.count > 2 {
                                    hasCerts = true
                                }
                            }
                            sendMoreAPDUCommands(apdu: getCert9D) { data, sw1, sw2 in
                                // 9D: Key Management cert
                                if sw1 == 0x90 && sw2 == 0x00 {
                                    os_log("9D bytes received: %{public}s", log: self.apduLog, type: .debug, "\(data.count)")
                                    if data.count > 2 {
                                        hasCerts = true
                                    }
                                }
                                sendMoreAPDUCommands(apdu: getCert9E) { data, sw1, sw2 in
                                    // 9E: Card Authentication cert
                                    if sw1 == 0x90 && sw2 == 0x00 {
                                        os_log("9E bytes received: %{public}s", log: self.apduLog, type: .debug, "\(data.count)")
                                        if data.count > 2 {
                                            hasCerts = true
                                        }
                                    }
                                    // Done probing; end the smartcard session and unblock the semaphore.
                                    card?.endSession()
                                    sema.signal()
                                    
                                }
                            }
                        }
                        
                    }
                } else {
                    card?.endSession()
                    sema.signal()
                }
            })
            
        })
        sema.wait()
        
        // Build a snapshot of the findings for the caller.
        let cardStatus: CardStatus = .init(readerName: slotName, isLocked: locked, hasCerts: hasCerts)
        
        return cardStatus
        
    }
    
}

/// MARK: - Delegates
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        insertExistingTokens()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }
}
/// Present banner notifications while app is in the foreground.
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler(.banner)
    }
    
}
