//
//  PreferencesViewController.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/2/24.
//
import ServiceManagement
import UserNotifications
import Cocoa

class PreferencesViewController: NSViewController {
    let notificationsButton = NSButton(checkboxWithTitle: "Allow Notifications", target: Any?.self, action: #selector(allowNotifications))

    override func loadView() {
        Task {
            await notificationPermissions()
        }
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
        startUpButton.frame = NSRect(x: 160, y: 70, width: 200, height: 25)
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
        
        
        notificationsButton.frame = NSRect(x: 160, y: 50, width: 200, height: 25)
        notificationsButton.toolTip = "Once checked, this is controlled through Notifications in System Settings."
        let infoTextView = NSTextView(frame: NSRect(x: 160, y: 95, width: 240, height: 100))
        infoTextView.textContainerInset = NSSize(width: 10, height: 10)
        infoTextView.isEditable = false
        infoTextView.isSelectable = true
        infoTextView.drawsBackground = false
        if let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let infoString = """
    SC Menu
    Version: \(versionText)
    
    https://github.com/boberito/sc_menu
    """
            
            let infoAttributedString = NSMutableAttributedString(string: infoString)

            let url = URL(string: "https://github.com/boberito/sc_menu")!
            let linkRange = (infoString as NSString).range(of: url.absoluteString)
            infoAttributedString.addAttribute(.link, value: url, range: linkRange)
            
            let boldFont = NSFont.boldSystemFont(ofSize: 17)
            let boldRange = (infoString as NSString).range(of: "SC Menu")
            infoAttributedString.addAttribute(.font, value: boldFont, range: boldRange)
            if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" {
                infoAttributedString.addAttribute(.foregroundColor, value: NSColor.white, range: boldRange)
                let versionRange = (infoString as NSString).range(of: "Version: \(versionText)")
                infoAttributedString.addAttribute(.foregroundColor, value: NSColor.white, range: versionRange)
            }
            infoTextView.textStorage?.setAttributedString(infoAttributedString)
            
        }
        let appIcon = NSImageView(frame:NSRect(x: 255, y:145, width: 40, height: 40))
        appIcon.image = NSImage(named: "AppIcon")
        
        view.addSubview(iconLabel)
        view.addSubview(startUpButton)
        view.addSubview(notificationsButton)
        view.addSubview(iconOneRadioButton)
        view.addSubview(iconTwoRadioButton)
        view.addSubview(iconOneImageOut)
        view.addSubview(iconOneImageIn)
        view.addSubview(iconTwoImageOut)
        view.addSubview(iconTwoImageIn)
        view.addSubview(infoTextView)
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
            NSLog("SC Menu - B&W Icon selected")
        }
        
        if sender.title == "Colorful" {
            UserDefaults.standard.set("colorful", forKey: "icon_mode")
            NSLog("SC Menu - Colorful Icon selected")
        }
    }
    
    @objc func allowNotifications(_ sender: NSButton) {
        let nc = UNUserNotificationCenter.current()
        
        nc.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                RunLoop.main.perform {
                    self.notificationsButton.intValue = 1
                    self.notificationsButton.isEnabled = false
                }
                NSLog("Notifications are allowed")
            } else {
                RunLoop.main.perform {
                    self.notificationsButton.intValue = 0
                    self.notificationsButton.isEnabled = false
                }
                NSLog("Notifications denied")
            }
        }
    
    }
    
    @objc func loginItemChange(_ sender: NSButton) {
        if sender.intValue == 1 {
            do {
                try SMAppService.mainApp.register()
                NSLog("SC Menu set to launch at login")
            } catch {
                NSLog("SMApp Service register error")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                NSLog("SC Menu removed from login items")
            } catch {
                NSLog("SMApp Service unregister error")
            }
        }
    }
    func notificationPermissions() async {
        let center = UNUserNotificationCenter.current()

        // Obtain the notification settings.
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized {
            notificationsButton.intValue = 1
            notificationsButton.isEnabled = false
        }
        if settings.authorizationStatus == .denied {
            notificationsButton.intValue = 0
            notificationsButton.isEnabled = false
        }
        if settings.authorizationStatus == .notDetermined {
            notificationsButton.isEnabled = true
            notificationsButton.intValue = 0
        }
        
    }

}
