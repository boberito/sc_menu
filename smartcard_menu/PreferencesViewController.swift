//
//  PreferencesViewController.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/2/24.
//
import ServiceManagement
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
        
        let iconOneImageOut = NSImageView(frame:NSRect(x: 25, y:130, width: 50, height: 40))
        iconOneImageOut.image = NSImage(named: "smartcard_out")
        let iconOneImageIn = NSImageView(frame:NSRect(x: 60, y:130, width: 50, height: 40))
        iconOneImageIn.image = NSImage(named: "smartcard_in")

        
        let iconTwoImageOut = NSImageView(frame:NSRect(x: 25, y:75, width: 50, height: 40))
        iconTwoImageOut.image = NSImage(named: "smartcard_out_bw")
        let iconTwoImageIn = NSImageView(frame:NSRect(x: 60, y:75, width: 50, height: 40))
        iconTwoImageIn.image = NSImage(named: "smartcard_in_bw")
        
        let iconOneRadioButton = NSButton(radioButtonWithTitle: "Color", target: Any?.self, action: #selector(changeIcon))
        iconOneRadioButton.frame = NSRect(x: 25, y: 110, width: 150, height: 25)
        iconOneRadioButton.title = "Option 1"
        
        let iconTwoRadioButton = NSButton(radioButtonWithTitle: "Color", target: Any?.self, action: #selector(changeIcon))
        iconTwoRadioButton.frame = NSRect(x: 25, y: 50, width: 150, height: 25)
        iconTwoRadioButton.title = "Option 2"
        
        let startUpButton = NSButton(checkboxWithTitle: "Start at Login", target: Any?.self, action: #selector(loginItemChange))
        startUpButton.frame = NSRect(x: 200, y: 160, width: 150, height: 25)
        switch SMAppService.mainApp.status {
            case .enabled:
                startUpButton.intValue = 1
            
            case .notFound:
                startUpButton.intValue = 0
            
            case .notRegistered:
                startUpButton.intValue = 0
            
            case .requiresApproval:
                startUpButton.intValue = 0
            
            default:
                startUpButton.intValue = 0
        }
        let infoVersionLabel = NSTextField(frame: NSRect(x: 150, y: 50, width: 200, height: 100))
        if let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let infoString = """
    Version: \(versionText)
    
    https://github.com/boberito/sc_menu
    """
            let infoAttributedString = NSAttributedString(string: infoString)
            infoVersionLabel.attributedStringValue = infoAttributedString
        }
        infoVersionLabel.isBordered = true
        infoVersionLabel.isEditable = false
        infoVersionLabel.lineBreakStrategy = .standard
        infoVersionLabel.drawsBackground = false
        
        
        view.addSubview(iconLabel)
        view.addSubview(startUpButton)
        view.addSubview(iconOneRadioButton)
        view.addSubview(iconTwoRadioButton)
        view.addSubview(iconOneImageOut)
        view.addSubview(iconOneImageIn)
        view.addSubview(iconTwoImageOut)
        view.addSubview(iconTwoImageIn)
        view.addSubview(infoVersionLabel)
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
    
    @objc func changeIcon(_ sender: NSButton) {
        //use UserDefaults
        
    }
    
    @objc func loginItemChange(_ sender: NSButton) {
        if sender.intValue == 1 {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("register error")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                print("unregister error")
            }
        }
    }


}
