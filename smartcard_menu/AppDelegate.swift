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

let subsystem = "com.ttinc.sc-menu"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, PrefDataModelDelegate {
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
    let prefViewController = PreferencesViewController()
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        prefViewController.delegate = self
        os_log("SC Menu launched", log: appLog, type: .default)
        let appService = SMAppService.mainApp
        if CommandLine.arguments.count > 1 {
            
            let arguments = CommandLine.arguments
            let stringarguments = String(describing: arguments)
            NSLog(stringarguments)
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
                    os_log("Problem unregistering service", log: self.prefsLog, type: .default)
                }
                
            }
//            NSApp.terminate(nil)
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
                    NSLog("registered service")
                } catch {
                    NSLog("problem registering service")
                }
            }
            
        }
        UserDefaults.standard.setValue(true, forKey: "afterFirstLaunch")
        let updater = UpdateCheck()
        _ = updater.check()
        NSApplication.shared.setActivationPolicy(.accessory)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            switch $0.modifierFlags.intersection(.deviceIndependentFlagsMask) {
            case [.option]:
                for seperatorLine in self.seperatorLines {
                    seperatorLine.isHidden = false
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
            }
        }
        
        notificationPermissions()
        startup()
    }
    
    func notificationPermissions() {
        nc.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                
                os_log("Notifications allowed", log: self.appLog, type: .default)
            } else {
                
                os_log("Notifications denied", log: self.appLog, type: .default)
            }
        }
        
    }
    
    @objc func screenUnlocked() {
        startup()
    }
    
    func insertExistingTokens(){
        
        guard let tokenIDs = myTKWatcher?.tokenIDs else {
            return
        }
        for token in tokenIDs {
            self.showReader(TkID: token)
            
            
        }
        
    }
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
        
        myTKWatcher?.setInsertionHandler({ tokenID in
            
            self.update(CTKTokenID: tokenID)
        })
        addQuit()
    }
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
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.contentViewController = prefViewController
        
    }
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
    func PEMKeyFromDERKey(_ data: Data, PEMType: String) -> String {
        let kCryptoExportImportManagerPublicKeyInitialTag = "-----BEGIN RSA PUBLIC KEY-----\n"
        let kCryptoExportImportManagerPublicKeyFinalTag = "-----END RSA PUBLIC KEY-----\n"
        
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
        //        savePanel.allowedFileTypes = [ "cer" ]
        savePanel.allowedContentTypes = [.x509Certificate]
        savePanel.allowsOtherFileTypes = true
        let certsPopup = NSPopUpButton(frame: NSRect(x: 55, y: 30, width: 400, height: 25), pullsDown: false)
        let sortedDictKeys = pemcerts.sorted(by: { $0.key < $1.key }).map(\.key)
        certsPopup.addItems(withTitles: sortedDictKeys)
        let formatPopup = NSPopUpButton(frame: NSRect(x: 55, y: 0, width: 100, height: 25), pullsDown: false)
        formatPopup.addItems(withTitles: ["PEM", "DER"])
        let formatPopupLabel = NSTextField(frame: NSRect(x: -40, y: 0, width: 100, height: 25))
        formatPopupLabel.stringValue = "Select Format: "
        formatPopupLabel.isBordered = false
        formatPopupLabel.isBezeled = false
        let certsPopUpLabel = NSTextField(frame: NSRect(x: -70, y: 30, width: 125, height:25))
        certsPopUpLabel.stringValue = "Select a Certificate: "
        certsPopUpLabel.isBordered = false
        certsPopUpLabel.isBezeled = false
        let accessoryView = NSView()
        accessoryView.frame = NSRect(x:0, y:0, width: 300, height: 75)
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
                    
                    return
                }
            }
        })
        savePanel.makeKeyAndOrderFront(nil)
        savePanel.orderFrontRegardless()
        
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
    }
    @objc func certSelected(_ sender: NSMenuItem) {
        let selectedCert = sender.representedObject as! SecIdentity
        
        var secRef: SecCertificate? = nil
        let certRefErr = SecIdentityCopyCertificate(selectedCert, &secRef)
        
        if certRefErr == 0 {
            let openWindows = NSApplication.shared.windows.filter { $0.isVisible }
            
            for openWindow in openWindows {
                if openWindow.title == sender.title {
                    // Activate the app before bringing the window to the front
                    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    openWindow.makeKeyAndOrderFront(nil)
                    openWindow.orderFrontRegardless() // Ensure it comes to front
                    return
                }
            }
            var window: CertWindow!
            let _wndW : CGFloat = 500
            let _wndH : CGFloat = 500
            window = CertWindow(contentRect:NSMakeRect(0,0,_wndW,_wndH),styleMask:[.titled, .closable], backing:.buffered, defer:false)
            let scrollView = NSScrollView()
            scrollView.borderType = .lineBorder
            scrollView.hasHorizontalScroller = true
            scrollView.hasVerticalScroller = true
            
            window.center()
            window.title = sender.title
            let certView = SFCertificateView()
            certView.setCertificate(secRef!)
            certView.setDetailsDisclosed(true)
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            certView.translatesAutoresizingMaskIntoConstraints = false
            
            scrollView.documentView = certView
            window.contentView = scrollView
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            
            os_log("Cert %{public}s selected", log: appLog, type: .default, sender.title.description)
        }
    }
    
    func showReader(TkID: String) {
        let readerName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName ?? TkID
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
                    if TkID.contains("apple")==true {
                        return;
                    }
                    let keychainLockedItem = NSMenuItem(title: "Keychain Locked Error Reading Smartcards", action: nil, keyEquivalent: "")
                    statusItem.menu?.insertItem(keychainLockedItem, at: 0)
                    addQuit()
                    return
                }
                statusItem.menu?.insertItem(readerMenuItem, at: 0)
                statusItem.menu?.setSubmenu(subMenu, for:  readerMenuItem)
                if let certDict = certViewing.getIdentity(pivToken: pivToken){
                    for dict in self.lockedDictArray {
                        if dict[TkID] == true {
                            let lockedMenuItem = NSMenuItem(title: "Smartcard Locked", action: nil, keyEquivalent: "")
                            subMenu.addItem(lockedMenuItem)
                            os_log("%{public}s is locked", log: appLog, type: .default, TkID.description)
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
                return()
            }
            
        }
    }
    @objc func cardInfo(_ sender: NSMenuItem) {
        
        let cardReader = sender.representedObject as! String
        for currentWindow in NSApplication.shared.windows {
            //                if currentWindow.title.contains("Additonal Card Information") {
            let identifier = cardReader
            if currentWindow.identifier == NSUserInterfaceItemIdentifier(cardReader) {
                
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue ==  identifier }) {
                    window.makeKeyAndOrderFront(nil)
                }
                //                NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                //                return
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
    
    func menuBarIcon(fileURLString: String) {
        RunLoop.main.perform {
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
    @objc func update(CTKTokenID: String) {
        var isCardLocked = false
        if myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName != nil {
            os_log("Smartcard Inserted %{public}s", log: appLog, type: .default, CTKTokenID.description)
            isCardLocked = self.isLocked(slotName: myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName)
            lockedDictArray.append([CTKTokenID:isCardLocked])
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
        
        
        
        myTKWatcher?.addRemovalHandler({ CTKTokenID in
            
            os_log("Smartcard Removed %{public}s", log: self.appLog, type: .default, CTKTokenID.description)
            if let index = self.lockedDictArray.firstIndex(where: { $0.keys.contains(CTKTokenID) }) {
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
            RunLoop.main.perform {
                
                for scMenuItem in self.statusItem.menu!.items {
                    if let scMenuItemRepresentedObj = scMenuItem.representedObject as? String {
                        if scMenuItemRepresentedObj == CTKTokenID {
                            self.statusItem.menu?.removeItem(scMenuItem)
                            self.addQuit()
                            break
                        }
                    }
                }
                
                if self.statusItem.menu?.item(withTitle: "No Smartcard Inserted") != nil {
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
                }
                
            }
        }, forTokenID: CTKTokenID)
    }
    
    func isLocked(slotName: String?) -> Bool {
        let sm = TKSmartCardSlotManager()
        var card : TKSmartCard? = nil
        let sema = DispatchSemaphore.init(value: 0)
        
        guard let slotName = slotName else { return false }
        sm.getSlot(withName: slotName, reply: { currentslot in
            card = currentslot?.makeSmartCard()
            sema.signal()
        })
        sema.wait()
        
        
        var locked = false
        card?.beginSession(reply: { something, error in
            let apid : [UInt8] = [0x00, 0xa4, 0x04, 0x00, 0x0b, 0xa0, 0x00, 0x00, 0x03, 0x08, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00 ]
            let pinVerifyNull : [UInt8] = [ 0x00, 0x20, 0x00, 0x80, 0x00]
            
            let apidRequest = Data(apid)
            let request2 = Data(pinVerifyNull)
            
            card?.transmit(apidRequest, reply: { data, error in
                if error == nil {
                    
                    card?.transmit(request2, reply: { data, error in
                        guard let data = data else { return }
                        let result = data.hexEncodedString()
                        
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
                        
                        sema.signal()
                    })
                } else {
                    
                    sema.signal()
                }
            })
            
        })
        sema.wait()
        
        // be nice and end the session
        
        card?.endSession()
        if locked {
            return true
        }
        
        return false
    }
    
}
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        insertExistingTokens()
    }
}
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler(.banner)
    }
    
}

