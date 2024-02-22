//
//  CertWindow.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/22/24.
//

import Cocoa

class CertWindow: NSWindow {
    override func close() {
        self.orderOut(NSApp)
    }
}
