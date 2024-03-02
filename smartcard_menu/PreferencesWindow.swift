//
//  PreferencesWindow.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 3/1/24.
//

import Cocoa
class PreferencesWindow: NSWindow {
    override func close() {
        self.orderOut(NSApp)
    }
}
