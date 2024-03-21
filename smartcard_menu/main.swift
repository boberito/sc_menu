//
//  main.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/20/24.
//

import Foundation
import AppKit

// 1
let app = NSApplication.shared
// 2
app.delegate = AppDelegate()
// 3
app.setActivationPolicy(.accessory)
// 4
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
