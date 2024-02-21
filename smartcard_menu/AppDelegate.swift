//
//  AppDelegate.swift
//  smartcard_menu
//
//  Created by Gendler, Bob (Fed) on 2/16/24.
//

import Cocoa
import CryptoTokenKit

//@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let certViewing = ViewCerts()

    
    var myTKWatcher: TKTokenWatcher? = nil
    var inUseTKWatchers: [TKTokenWatcher.TokenInfo?] = []
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let nothingInsertedMenu = NSMenuItem(title: "No Smartcard Inserted", action: nil, keyEquivalent: "")
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
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
//            self.update()
        })
        addQuit()
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
                let subMenu = NSMenu()
                if statusItem.menu?.index(of: nothingInsertedMenu) != -1 {
                    statusItem.menu?.removeItem(nothingInsertedMenu)
                }
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
                            }
                        }
                    }
                }
                if self.inUseTKWatchers.count == 0 {
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
                
            }
        }, forTokenID: CTKTokenID)
    }

}

