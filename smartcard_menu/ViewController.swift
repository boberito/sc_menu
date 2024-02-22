//
//  ViewController.swift
//  smartcard_menu
//
//  Created by Gendler, Bob (Fed) on 2/16/24.
//

import Cocoa

class ViewController: NSViewController {
    override func loadView() {
      self.view = NSView()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        print("did it get made?")
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

