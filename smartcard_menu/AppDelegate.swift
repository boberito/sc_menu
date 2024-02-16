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
    
    typealias handler = (String) -> Swift.Void
    let myHandler: handler = { tokenID in
        DispatchQueue.main.async {
            NotificationQueue.default.enqueue( Notification(name: Notification.Name(rawValue: kNotificationRemove), object: nil), postingStyle: .now, coalesceMask: .onName, forModes: nil)
        }
    }
    
    var myTKWatcher: TKTokenWatcher? = nil
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        myTKWatcher = TKTokenWatcher.init()
        myTKWatcher?.setInsertionHandler(myHandler)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSNotification.Name(rawValue: kNotificationRemove), object: nil)
        
        
        update()
        statusItem.menu = NSMenu()
//        let itemOne = NSMenuItem(title: "Stuff", action: #selector(stuff), keyEquivalent: "")
//        statusItem.menu?.addItem(itemOne)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc func update() {
        if let tokenCount = myTKWatcher?.tokenIDs, let tokenWatcher = myTKWatcher {
            for CTKTokenID in tokenCount {
                if tokenWatcher.tokenInfo(forTokenID: CTKTokenID)?.slotName != nil {
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
                
                    myTKWatcher?.addRemovalHandler(myHandler, forTokenID: CTKTokenID)
                    return()
                }
                
            }

            if let fileURLString = Bundle.main.path(forResource: "smartcard_out", ofType: "png") {
                let fileExists = FileManager.default.fileExists(atPath: fileURLString)
                    if fileExists {
                        if let button = statusItem.button {
                            
                            button.image = NSImage(byReferencingFile: fileURLString)
                        }
                    } else {
                        statusItem.button?.title = "NOT Inserted"
                    }
            }

        }
    }
//    @objc func stuff(_ sender: NSMenuItem) {
//        print("Hello world")
//        print(myTKWatcher?.tokenIDs.count)
//        if let tokenCount = myTKWatcher?.tokenIDs {
//            for CTKToken in tokenCount {
//                print("--------")
//                                print(myTKWatcher?.tokenInfo(forTokenID: CTKToken)?.tokenID)
//                                print(myTKWatcher?.tokenInfo(forTokenID: CTKToken)?.slotName)
//
//                print(myTKWatcher?.tokenInfo(forTokenID: CTKToken)?.driverName)
//            }
//        }
//        
//    }
}

