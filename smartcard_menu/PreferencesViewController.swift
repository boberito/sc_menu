//
//  PreferencesViewController.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/2/24.
//
import ServiceManagement
import UserNotifications
import Cocoa
import os

protocol PrefDataModelDelegate {
    func didRecievePrefUpdate()
}

class PreferencesViewController: NSViewController {
    var delegate: PrefDataModelDelegate?
    private let prefsLog = OSLog(subsystem: subsystem, category: "Preferences")
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
        startUpButton.frame = NSRect(x: 160, y: 90, width: 200, height: 25)
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
        
        

        let updateButton = NSButton(title: "Check for Updates", target: Any?.self, action: #selector(updateCheck))
        updateButton.frame = NSRect(x: 155, y: 50, width: 150, height: 30)
        let infoTextView = NSTextView(frame: NSRect(x: 148, y: 110, width: 240, height: 25))
//        let infoTextView = NSTextView(frame: NSRect(x: 160, y: 95, width: 240, height: 100))
        infoTextView.textContainerInset = NSSize(width: 10, height: 10)
        infoTextView.isEditable = false
        infoTextView.isSelectable = true
        infoTextView.drawsBackground = false
        guard let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {return}
            let title = "SC Menu"
        
        let version = "Version: \(versionText)"
//        let versionTextView = NSTextField(frame: NSRect(x: 140, y: 140, width: 200, height: 40))
        let titleTextView = NSTextField(frame: NSRect(x: 160, y: 145, width: 100, height: 40))
        
        titleTextView.font = NSFont.boldSystemFont(ofSize: 16)
        titleTextView.isBordered = false
        titleTextView.isBezeled = false
        titleTextView.isEditable = false
        titleTextView.drawsBackground = false
        titleTextView.stringValue = title
        
        let versionTextView = NSTextField(frame: NSRect(x: 160, y: 125, width: 100, height: 40))
        versionTextView.isBordered = false
        versionTextView.isBezeled = false
        versionTextView.isEditable = false
        versionTextView.drawsBackground = false
        versionTextView.stringValue = version
            let infoString = "https://github.com/boberito/sc_menu"
            
            let infoAttributedString = NSMutableAttributedString(string: infoString)
            
            let url = URL(string: "https://github.com/boberito/sc_menu")!
            let linkRange = (infoString as NSString).range(of: url.absoluteString)
            infoAttributedString.addAttribute(.link, value: url, range: linkRange)
//
//            let boldFont = NSFont.boldSystemFont(ofSize: 17)
//            let boldRange = (infoString as NSString).range(of: "SC Menu")
//            infoAttributedString.addAttribute(.font, value: boldFont, range: boldRange)
//            if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" {
//                infoAttributedString.addAttribute(.foregroundColor, value: NSColor.white, range: boldRange)
//                let versionRange = (infoString as NSString).range(of: "Version: \(versionText)")
//                infoAttributedString.addAttribute(.foregroundColor, value: NSColor.white, range: versionRange)
//            }
            infoTextView.textStorage?.setAttributedString(infoAttributedString)
            
//        }
        let appIcon = NSImageView(frame:NSRect(x: 255, y:145, width: 40, height: 40))
        appIcon.image = NSImage(named: "AppIcon")
        
        view.addSubview(iconLabel)
        view.addSubview(startUpButton)
        view.addSubview(iconOneRadioButton)
        view.addSubview(iconTwoRadioButton)
        view.addSubview(iconOneImageOut)
        view.addSubview(iconOneImageIn)
        view.addSubview(iconTwoImageOut)
        view.addSubview(titleTextView)
        view.addSubview(iconTwoImageIn)
        view.addSubview(versionTextView)
        view.addSubview(infoTextView)
        view.addSubview(appIcon)
        view.addSubview(updateButton)
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
            os_log("B&W Icon selected", log: prefsLog, type: .default)
            self.delegate?.didRecievePrefUpdate()
            
        }
        
        if sender.title == "Colorful" {
            UserDefaults.standard.set("colorful", forKey: "icon_mode")
            os_log("Colorful Icon selected", log: prefsLog, type: .default)
            self.delegate?.didRecievePrefUpdate()
        }
    }
    
    @objc func updateCheck(_ sender: NSButton) {
        os_log("Update button pressed", log: prefsLog, type: .default)
        let updater = UpdateCheck()
        switch updater.check() {
        case 1:
            return
        case 2:
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = """
            Cannot reach GitHub to check SC Menu updates.
            """
            alert.runModal()
        default:
            let alert = NSAlert()
            alert.messageText = "No Update Available"
            alert.informativeText = """
            SC Menu is currently up to date.
            """
            alert.runModal()
        }
        
    }
    
    
    @objc func loginItemChange(_ sender: NSButton) {
        if sender.intValue == 1 {
            do {
                try SMAppService.mainApp.register()
                os_log("SC Menu set to launch at login", log: self.prefsLog, type: .default)
            } catch {
                os_log("SMApp Service register error %s", log: self.prefsLog, type: .error, error.localizedDescription)
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                os_log("SC Menu removed from login items", log: self.prefsLog, type: .default)
            } catch {
                os_log("SMApp Service unregister error %s", log: self.prefsLog, type: .default, error.localizedDescription)
            }
        }
    }


}
