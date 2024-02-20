//
//  AppDelegate.swift
//  smartcard_menu
//
//  Created by Gendler, Bob (Fed) on 2/16/24.
//

import Cocoa
import CryptoTokenKit

//@main
let kNotificationRemove = "com.bob.smartcard-menu"

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let certViewing = ViewCerts()
    typealias handler = (String) -> Swift.Void
    let myHandler: handler = { tokenID in
        DispatchQueue.main.async {
            NotificationQueue.default.enqueue( Notification(name: Notification.Name(rawValue: kNotificationRemove), object: nil), postingStyle: .now, coalesceMask: .onName, forModes: nil)
        }
    }
    
    var myTKWatcher: TKTokenWatcher? = nil
    var slotName: String?
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let nothingInsertedMenu = NSMenuItem(title: "No Smartcard Inserted", action: nil, keyEquivalent: "")
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        myTKWatcher = TKTokenWatcher.init()
        myTKWatcher?.setInsertionHandler(myHandler)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSNotification.Name(rawValue: kNotificationRemove), object: nil)
        
        
        update()
        statusItem.menu = NSMenu()
        statusItem.menu?.insertItem(nothingInsertedMenu, at: 0)
        
        
        statusItem.menu?.addItem(NSMenuItem.separator())
        let quitMenu = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        statusItem.menu?.addItem(quitMenu)
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
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func showReader(TkID: String) {
        if let readerName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName, let pivToken = myTKWatcher?.tokenInfo(forTokenID: TkID)?.tokenID {
            let readerMenuItem = NSMenuItem(title: readerName, action: nil, keyEquivalent: "")
            let readerMenuItemExists = statusItem.menu?.item(withTitle: readerName)
            if readerMenuItemExists == nil {
                statusItem.menu?.removeItem(at: 0)
                let subMenu = NSMenu()
                statusItem.menu?.insertItem(readerMenuItem, at: 0)
                statusItem.menu?.setSubmenu(subMenu, for:  readerMenuItem)
                
                if let certLabels = certViewing.getIdentity(pivToken: pivToken)?.sorted() {
                    var seperator = false
                    for certLabel in certLabels {
                        if certLabel.contains("Retired") && !seperator {
                            subMenu.addItem(NSMenuItem.separator())
                            seperator = true
                        }
                        let label = NSMenuItem(title: certLabel, action: nil, keyEquivalent: "")
                        subMenu.addItem(label)
                    }
                }
                
            } else {
                return()
            }
            
        }
    }
    
    @objc func quit() {
        exit(0)
    }
    @objc func update() {
        
        if let tokenCount = myTKWatcher?.tokenIDs, let tokenWatcher = myTKWatcher {
            for CTKTokenID in tokenCount {
                
                if tokenWatcher.tokenInfo(forTokenID: CTKTokenID)?.slotName != nil {
                    slotName = tokenWatcher.tokenInfo(forTokenID: CTKTokenID)?.slotName
                    if let fileURLString = Bundle.main.path(forResource: "smartcard_in", ofType: "png") {
                        let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                            if fileExists {
                                if let button = statusItem.button {
                                    
                                    button.image = NSImage(byReferencingFile: fileURLString)
                                }
                            } else {
                                statusItem.button?.title = "Inserted"
                            }
                    }
                    
                    showReader(TkID: CTKTokenID)
                    
                    
                    myTKWatcher?.addRemovalHandler({ _ in
                        
                        RunLoop.main.perform {
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
                            
                            if let slotName = self.slotName {
                                if let menuIndex = self.statusItem.menu?.indexOfItem(withTitle: slotName) {
                                    self.statusItem.menu?.removeItem(at: menuIndex)
                                    self.statusItem.menu?.insertItem(self.nothingInsertedMenu, at: 0)
                                }
                            }
                        }
                    }, forTokenID: CTKTokenID)
                    return()
                    
                }
                
            }

        }
    }
}

