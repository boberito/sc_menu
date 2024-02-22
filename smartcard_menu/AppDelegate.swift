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

//@main
class AppDelegate: NSObject, NSApplicationDelegate {
    let certViewing = ViewCerts()
    
    var code: Any?
    
    var myTKWatcher: TKTokenWatcher? = nil
    var inUseTKWatchers: [TKTokenWatcher.TokenInfo?] = []
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let nothingInsertedMenu = NSMenuItem(title: "No Smartcard Inserted", action: nil, keyEquivalent: "")
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)),
                                                              name: NSWorkspace.didWakeNotification, object: nil)
        inUseTKWatchers.removeAll()
        
        startup()
    }
    func startup() {
        myTKWatcher = TKTokenWatcher.init()
        
        myTKWatcher?.setInsertionHandler({ tokenID in
            self.update(CTKTokenID: tokenID)
        })

        statusItem.menu = NSMenu()
        statusItem.menu?.insertItem(nothingInsertedMenu, at: 0)
        
        if let fileURLString = Bundle.main.path(forResource: "smartcard_out", ofType: "png") {
            let fileExists = FileManager.default.fileExists(atPath: fileURLString)
            //                                removeReaderMenu()
            if fileExists {
                if let button = self.statusItem.button {
                    button.image = NSImage(byReferencingFile: fileURLString)
                }
            } else {
                self.statusItem.button?.title = "NOT Inserted"
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
    
    @objc func certSelected(_ sender: NSMenuItem) {
        let selectedCert = sender.representedObject as! SecIdentity
        
        var secRef: SecCertificate? = nil
            let certRefErr = SecIdentityCopyCertificate(selectedCert, &secRef)
        
            if certRefErr == 0 {

                var window: CertWindow!
                let windowController = NSWindowController(
                    window: window)
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
            let quitMenu = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
            statusItem.menu?.addItem(quitMenu)
        }
        
        if statusItem.menu?.indexOfItem(withTitle: "Quit") == 1 {
            statusItem.menu?.insertItem(self.nothingInsertedMenu, at: 0)
        }
        
    }
    
    @objc func update(CTKTokenID: String) {
        if myTKWatcher?.tokenInfo(forTokenID: CTKTokenID)?.slotName != nil {
            inUseTKWatchers.append(myTKWatcher!.tokenInfo(forTokenID: CTKTokenID))
            if let fileURLString = Bundle.main.path(forResource: "smartcard_in", ofType: "png") {
                RunLoop.main.perform {
                    let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                    if fileExists {
                        if let button = self.statusItem.button {
                            
                            button.image = NSImage(byReferencingFile: fileURLString)
                            
                            
                        }
                    } else {
                        self.statusItem.button?.title = "Inserted"
                    }
                }
                
                showReader(TkID: CTKTokenID)
            }
        }
        
        myTKWatcher?.addRemovalHandler({ CTKTokenID in
            RunLoop.main.perform {
                for inUseTKWatcher in self.inUseTKWatchers {
                    if inUseTKWatcher?.tokenID == CTKTokenID {
                        if let slotName = inUseTKWatcher?.slotName {
                            if let menuIndex = self.statusItem.menu?.indexOfItem(withTitle: slotName) {
                                self.statusItem.menu?.removeItem(at: menuIndex)
                                let index = self.inUseTKWatchers.firstIndex(of: inUseTKWatcher)
                                self.inUseTKWatchers.remove(at: index!)
                                self.addQuit()
                                break
                            }
                        }
                    }
                }
                
                if self.statusItem.menu?.item(withTitle: "No Smartcard Inserted") != nil {
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
        }, forTokenID: CTKTokenID)
    }

}

