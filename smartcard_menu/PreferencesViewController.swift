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

        let rect = NSRect(x: 0, y: 0, width: 415, height: 200)
        view = NSView(frame: rect)
        view.wantsLayer = true
        
        let iconLabel = NSTextField(frame: NSRect(x: 20, y: 160, width: 150, height: 25))
        iconLabel.stringValue = "Select Menu Icon"
        iconLabel.isBordered = false
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.drawsBackground = false
        
        let iconOneImageOut = NSImageView(frame:NSRect(x: 20, y:130, width: 50, height: 40))
        iconOneImageOut.image = NSImage(named: "smartcard_out")
        let iconOneImageIn = NSImageView(frame:NSRect(x: 55, y:130, width: 50, height: 40))
        iconOneImageIn.image = NSImage(named: "smartcard_in")

        
        let iconTwoImageOut = NSImageView(frame:NSRect(x: 20, y:75, width: 50, height: 40))
        iconTwoImageOut.image = NSImage(named: "smartcard_out_bw")
        let iconTwoImageIn = NSImageView(frame:NSRect(x: 55, y:75, width: 50, height: 40))
        iconTwoImageIn.image = NSImage(named: "smartcard_in_bw")
        
        let iconOneRadioButton = NSButton(radioButtonWithTitle: "Color", target: Any?.self, action: #selector(changeIcon))
        iconOneRadioButton.frame = NSRect(x: 20, y: 110, width: 150, height: 25)
        iconOneRadioButton.title = "Colorful"
        
        let iconTwoRadioButton = NSButton(radioButtonWithTitle: "Color", target: Any?.self, action: #selector(changeIcon))
        iconTwoRadioButton.frame = NSRect(x: 20, y: 50, width: 150, height: 25)
        iconTwoRadioButton.title = "Black and White"
        if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
            iconTwoRadioButton.state = .on
            iconOneRadioButton.state = .off
        } else {
            iconOneRadioButton.state = .on
            iconTwoRadioButton.state = .off
        }
        
        let startUpButton = NSButton(checkboxWithTitle: "Launch SC Menu at Login", target: Any?.self, action: #selector(loginItemChange))
//        startUpButton.frame = NSRect(x: 160, y: 160, width: 150, height: 25)
        startUpButton.frame = NSRect(x: 160, y: 50, width: 200, height: 25)
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
//        let infoVersionLabel = NSTextField(frame: NSRect(x: 160, y: 50, width: 240, height: 100))
                let infoVersionLabel = NSTextField(frame: NSRect(x: 160, y: 85, width: 240, height: 100))
        if let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let infoString = """
    SC Menu
    Version: \(versionText)
    
    https://github.com/boberito/sc_menu
    """
            let urlLength = infoString.split(separator: "\n")[2].count
            let titleLength = infoString.split(separator: "\n")[0].count
            let versionLength = infoString.split(separator: "\n")[1].count
            
//            let firstAttributes: [NSAttributedString.Key: Any] = [.backgroundColor: UIColor.green, NSAttributedString.Key.kern: 10]
            let infoAttributedString = NSMutableAttributedString(string: infoString)
            infoAttributedString.addAttribute(.link, value: "https://github.com/boberito/sc_menu", range: NSRange(location: titleLength + versionLength + 3, length: urlLength ))
            
            let boldFont = NSFont.boldSystemFont(ofSize: 17)
            let boldRange = (infoString as NSString).range(of: "SC Menu")
            infoAttributedString.addAttribute(.font, value: boldFont, range: boldRange)

            infoVersionLabel.attributedStringValue = infoAttributedString
        }
        infoVersionLabel.isBordered = false
        infoVersionLabel.isEditable = false
        infoVersionLabel.lineBreakStrategy = .standard
        infoVersionLabel.drawsBackground = false
        
        let appIcon = NSImageView(frame:NSRect(x: 255, y:145, width: 40, height: 40))
        appIcon.image = NSImage(named: "AppIcon")
        
        view.addSubview(iconLabel)
        view.addSubview(startUpButton)
        view.addSubview(iconOneRadioButton)
        view.addSubview(iconTwoRadioButton)
        view.addSubview(iconOneImageOut)
        view.addSubview(iconOneImageIn)
        view.addSubview(iconTwoImageOut)
        view.addSubview(iconTwoImageIn)
        view.addSubview(infoVersionLabel)
        view.addSubview(appIcon)
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
        
        if sender.title == "Black and White" {
            UserDefaults.standard.set("bw", forKey: "icon_mode")
        }
        
        if sender.title == "Colorful" {
            UserDefaults.standard.set("colorful", forKey: "icon_mode")
        }
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
