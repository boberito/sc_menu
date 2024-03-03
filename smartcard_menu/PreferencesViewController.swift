//
//  PreferencesViewController.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/2/24.
//

import Cocoa

class PreferencesViewController: NSViewController {
    override func loadView() {

        let rect = NSRect(x: 0, y: 0, width: 400, height: 200)
        view = NSView(frame: rect)
        view.wantsLayer = true
        
        let iconLabel = NSTextField(frame: NSRect(x: 25, y: 160, width: 150, height: 25))
        iconLabel.stringValue = "Select Menu Icon"
        iconLabel.isBordered = false
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.drawsBackground = false
        
        let startUpLabel = NSTextField(frame: NSRect(x: 200, y: 160, width: 150, height: 25))
        startUpLabel.stringValue = "Start at Login"
        startUpLabel.isBordered = false
        startUpLabel.isBezeled = false
        startUpLabel.isEditable = false
        startUpLabel.drawsBackground = false

        let startUpButton = NSButton(checkboxWithTitle: "Start at Login", target: Any?.self, action: #selector(loginItemChange))
        startUpButton.frame = NSRect(x: 200, y: 160, width: 150, height: 25)
        
        view.addSubview(iconLabel)
//        view.addSubview(startUpLabel)
        view.addSubview(startUpButton)
//
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @objc func loginItemChange() {
        print("blah blah blah")
    }


}
