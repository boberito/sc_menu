//
//  MyInfoWindow.swift
//  SC Menu
//
//  Created by Bob Gendler on 11/1/24.
//

import Cocoa
class MyInfoWindow: NSWindow {
    override func close() {
        self.orderOut(NSApp)
    }
}
