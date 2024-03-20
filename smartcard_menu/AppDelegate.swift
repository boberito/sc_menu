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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let certViewing = ViewCerts()
    
    var code: Any?
    var debugMenuItems = [NSMenuItem]()
    var seperatorLines = [NSMenuItem]()
    var exportMenuItems = [NSMenuItem]()
    var myTKWatcher: TKTokenWatcher? = nil
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let nothingInsertedMenu = NSMenuItem(title: "No Smartcard Inserted", action: nil, keyEquivalent: "")
    let iconPref = UserDefaults.standard.string(forKey: "icon_mode") ?? "light"
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
        startup()
    }
    
    @objc func screenUnlocked() {
        startup()
    }
    
    func startup() {
//        if let image = NSImage(systemSymbolName: "exclamationmark.warninglight",
//                               accessibilityDescription: "A multiply symbol inside a filled circle.") {
//                
//            var config = NSImage.SymbolConfiguration(textStyle: .body,
//                                                             scale: .large)
//            config = config.applying(.init(paletteColors: [.systemTeal, .systemGray]))
////            imageView.image = image.withSymbolConfiguration(config)
//            
//        }

        
        var x = statusItem.menu?.propertiesToUpdate
        myTKWatcher = TKTokenWatcher.init()
        statusItem.menu = NSMenu()
        statusItem.menu?.insertItem(nothingInsertedMenu, at: 0)
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
        // Insert code here to tear down your application
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    @objc func preferencesWindow(_ sender: NSMenuItem) {
        
        for currentWindow in NSApplication.shared.windows {
            if currentWindow.title.contains("SC Menu Preferences") {
                if #available(OSX 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                return
            }
        }
        var window: PreferencesWindow?
        let windowSize = NSSize(width: 415, height: 200)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        window = PreferencesWindow(contentRect: rect, styleMask: [.miniaturizable, .closable, .titled], backing: .buffered, defer: false)
        window?.title = "SC Menu Preferences"
        if #available(OSX 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
        window?.contentViewController = PreferencesViewController()
        
    }
    @objc func ATRfunc(_ sender: NSMenuItem) {
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
            if #available(OSX 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            window.makeKeyAndOrderFront(window)
        }
        
//
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
                            print("Error getting public certificate.")
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
        savePanel.makeKeyAndOrderFront(savePanel)
        savePanel.orderFrontRegardless()
        if #available(OSX 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        
    }
    @objc func certSelected(_ sender: NSMenuItem) {
        let selectedCert = sender.representedObject as! SecIdentity
        
        var secRef: SecCertificate? = nil
        let certRefErr = SecIdentityCopyCertificate(selectedCert, &secRef)
        
        if certRefErr == 0 {
            
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
            if #available(OSX 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            window.makeKeyAndOrderFront(window)
            
        }
    }
    
    func showReader(TkID: String) {
        if let readerName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName, let pivToken = myTKWatcher?.tokenInfo(forTokenID: TkID)?.tokenID {
            let readerMenuItem = NSMenuItem(title: readerName, action: nil, keyEquivalent: "")
            readerMenuItem.representedObject = TkID
            let readerMenuItemExists = statusItem.menu?.item(withTitle: readerName)
            if readerMenuItemExists == nil {
                let subMenu = NSMenu()
                if statusItem.menu?.index(of: nothingInsertedMenu) != -1 {
                    statusItem.menu?.removeItem(nothingInsertedMenu)
                }
                statusItem.menu?.insertItem(readerMenuItem, at: 0)
                statusItem.menu?.setSubmenu(subMenu, for:  readerMenuItem)
                if let certDict = certViewing.getIdentity(pivToken: pivToken){
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
    
    @objc func quit() {
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
        }
        
    }
    
    @objc func update(CTKTokenID: String) {
        var isCardLocked = false
        if myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName != nil {
            isCardLocked = self.isLocked(slotName: myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName)
            if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
                if let fileURLString = Bundle.main.path(forResource: "smartcard_in_bw", ofType: "png") {
                    RunLoop.main.perform {
                        let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                        if fileExists {
                            if let button = self.statusItem.button {
                                let buttonImage = NSImage(byReferencingFile: fileURLString)
                                if isCardLocked {
                                    if let buttonImage = NSImage(byReferencingFile: fileURLString){
                                        
                                        let circleSize = NSSize(width: 10, height: 10)
                                        let circleOrigin = NSPoint(x: buttonImage.size.width - circleSize.width, y: buttonImage.size.height - circleSize.height)
                                        
                                        // Create a red circle image
                                        let redCircleImage = NSImage(size: buttonImage.size, flipped: false) { (newImageRect: NSRect) -> Bool in
                                            // Draw the buttonImage
                                            buttonImage.draw(in: newImageRect)
                                            
                                            // Draw the red circle
                                            let circlePath = NSBezierPath(ovalIn: NSRect(origin: circleOrigin, size: circleSize))
                                            NSColor.red.setFill()
                                            circlePath.fill()
                                            
                                            return true
                                        }
                                        
                                        guard let newImageRef = redCircleImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                            fatalError("Failed to create CGImage")
                                        }
                                        button.image = redCircleImage
                                    }
                                } else {
                                    button.image = NSImage(byReferencingFile: fileURLString)
                                }
//                                button.image = NSImage(byReferencingFile: fileURLString)

                            }
                        } else {
                            self.statusItem.button?.title = "Inserted"
                        }
                    
                    
                        self.showReader(TkID: CTKTokenID)
                    }
                }
            } else {
                if let fileURLString = Bundle.main.path(forResource: "smartcard_in", ofType: "png") {
                    RunLoop.main.perform {
                        let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                        if fileExists {
                            
                            if let button = self.statusItem.button {
                                
                                let buttonImage = NSImage(byReferencingFile: fileURLString)
                                if isCardLocked {
                                    if let buttonImage = NSImage(byReferencingFile: fileURLString){
                                        
                                        let circleSize = NSSize(width: 10, height: 10)
                                        let circleOrigin = NSPoint(x: buttonImage.size.width - circleSize.width, y: buttonImage.size.height - circleSize.height)
                                        
                                        // Create a red circle image
                                        let redCircleImage = NSImage(size: buttonImage.size, flipped: false) { (newImageRect: NSRect) -> Bool in
                                            // Draw the buttonImage
                                            buttonImage.draw(in: newImageRect)
                                            
                                            // Draw the red circle
                                            let circlePath = NSBezierPath(ovalIn: NSRect(origin: circleOrigin, size: circleSize))
                                            NSColor.red.setFill()
                                            circlePath.fill()
                                            
                                            return true
                                        }
                                        
                                        guard let newImageRef = redCircleImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                            fatalError("Failed to create CGImage")
                                        }
                                        button.image = redCircleImage
                                    }
                                    //                                button.image = NSImage(byReferencingFile: fileURLString)
                                    
                                } else {
                                    button.image = NSImage(byReferencingFile: fileURLString)
                                }
                            }
                            
                        } else {
                            self.statusItem.button?.title = "Inserted"
                        }
                        
                        
                        self.showReader(TkID: CTKTokenID)
                    }
                }
            }
        }
        if isCardLocked {
//            self.statusItem.button?.title = "!"
            print("locked")
        }
        
        
        
        myTKWatcher?.addRemovalHandler({ CTKTokenID in
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
        let slots = sm.slotNames.filter { $0 != "TCS Virtual Serial" }
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
                        
                        let result = data!.hexEncodedString()
                        
                        // convert from hex to decimal
                        
                        let attempts = Int(String(result.last!), radix: 16)
                        
//                        var attemptsText = ""
                        
                        // if attempts left == 0, card is locked
                        // otherwise print attempts
                        // unless we didn't get a success code
                        
                        if attempts == 0 {
                            locked = true
                        } else {
                            locked = false
                        }
                        
                        // check for "63" in the sequence
                        // TODO: check just first two words
                        
                        if !String(describing: data!.hexEncodedString()).contains("63") {
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

