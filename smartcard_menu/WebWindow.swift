//
//  WebWindow.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/29/24.
//

import Cocoa

class WebWindow: NSWindow {
    override func close() {
        self.orderOut(NSApp)
    }
}
