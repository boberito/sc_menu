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
import UniformTypeIdentifiers

/// Notifies listeners (like `AppDelegate`) when a preference that affects UI or behavior changes,
/// so they can refresh state (e.g., update status bar icon).
protocol PrefDataModelDelegate: AnyObject {
    func didReceivePrefUpdate()
}

/// Handles the SC Menu Preferences window. Builds controls programmatically, reads/writes
/// UserDefaults, and triggers app-level updates via `PrefDataModelDelegate`.
///
/// Key preferences:
/// - Icon appearance (color vs. black & white)
/// - Notifications enabled
/// - Launch at login
/// - Run scripts on insert/removal (with chosen script paths)
class PreferencesViewController: NSViewController {
    // MARK: - Script Path UI & Storage
    private var runAtInsertPathField: NSTextField!
    private var runAtRemovalPathField: NSTextField!

    private var runAtInsertScriptPath: String? {
        didSet {
            let name = runAtInsertScriptPath.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
            runAtInsertPathField?.stringValue = name
        }
    }
    private var runAtRemovalScriptPath: String? {
        didSet {
            let name = runAtRemovalScriptPath.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
            runAtRemovalPathField?.stringValue = name
        }
    }
    
    weak var delegate: PrefDataModelDelegate?
    private let prefsLog = OSLog(subsystem: subsystem, category: "Preferences")
    
    override func loadView() {
        // Build the entire preferences UI in code (no XIB/Storyboard). Also initializes
        // controls with current values from UserDefaults and system state (e.g., login item).
        guard let appBundleID = Bundle.main.bundleIdentifier else { return }
        let rect = NSRect(x: 0, y: 0, width: 415, height: 225)
        view = NSView(frame: rect)
        view.wantsLayer = true
        
        let iconLabel = NSTextField(frame: NSRect(x: 20, y: 185, width: 150, height: 25))
        iconLabel.stringValue = "Select Menu Icon"
        iconLabel.isBordered = false
        iconLabel.isBezeled = false
        iconLabel.isEditable = false
        iconLabel.drawsBackground = false
        
        let iconOneImageOut = NSImageView(frame:NSRect(x: 20, y:155, width: 50, height: 40))
        iconOneImageOut.image = NSImage(named: "smartcard_out")
        let iconOneImageIn = NSImageView(frame:NSRect(x: 55, y:155, width: 50, height: 40))
        iconOneImageIn.image = NSImage(named: "smartcard_in")
        
        
        let iconTwoImageOut = NSImageView(frame:NSRect(x: 20, y:100, width: 50, height: 40))
        iconTwoImageOut.image = NSImage(named: "smartcard_out_bw")
        let iconTwoImageIn = NSImageView(frame:NSRect(x: 55, y:100, width: 50, height: 40))
        iconTwoImageIn.image = NSImage(named: "smartcard_in_bw")
        
        let iconOneRadioButton = NSButton(radioButtonWithTitle: "Color", target: Any?.self, action: #selector(changeIcon))
        iconOneRadioButton.frame = NSRect(x: 20, y: 135, width: 150, height: 25)
        iconOneRadioButton.title = "Colorful"
        
        let iconTwoRadioButton = NSButton(radioButtonWithTitle: "Color", target: Any?.self, action: #selector(changeIcon))
        iconTwoRadioButton.frame = NSRect(x: 20, y: 75, width: 150, height: 25)
        iconTwoRadioButton.title = "Black and White"
        if UserDefaults.standard.string(forKey: "icon_mode") == "bw" {
            iconTwoRadioButton.state = .on
            iconOneRadioButton.state = .off
        } else {
            iconOneRadioButton.state = .on
            iconTwoRadioButton.state = .off
        }
        
        let notificationsButton = NSButton(checkboxWithTitle: "Show Notifications", target: Any?.self, action: #selector(notificationChange))
        notificationsButton.frame = NSRect(x: 20, y: 45, width: 200, height: 25)
        
        let nc = UNUserNotificationCenter.current()
        Task {
            let settings = await nc.notificationSettings()
            if settings.authorizationStatus == .authorized {
                if UserDefaults.standard.bool(forKey: "show_notifications") {
                    notificationsButton.state = .on
                } else {
                    notificationsButton.state = .off
                }
                
            } else {
                notificationsButton.state = .off
                notificationsButton.isEnabled = false
            }
            
        }
        let startUpButton = NSButton(checkboxWithTitle: "Launch SC Menu at Login", target: Any?.self, action: #selector(loginItemChange))

        startUpButton.frame = NSRect(x: 20, y: 15, width: 200, height: 25)
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
        
        let runAtInsertButton = NSButton(checkboxWithTitle: "Run Script On Insert", target: Any?.self, action: #selector(runOnInsertChange))
        if UserDefaults.standard.bool(forKey: "run_on_insert") {
            runAtInsertButton.state = .on
        }
        let isRunInsertForced = CFPreferencesAppValueIsForced("run_on_insert" as CFString, appBundleID as CFString)
        if isRunInsertForced {
            runAtInsertButton.isEnabled = false
        }
        
        
        runAtInsertButton.frame = NSRect(x: 185, y: 120, width: 200, height: 25)
        
        self.runAtInsertPathField = NSTextField(frame: NSRect(x: 185, y: 100, width: 125, height: 20))
        self.runAtInsertPathField.drawsBackground = true
        self.runAtInsertPathField.isSelectable = false
        self.runAtInsertPathField.isBordered = true
        if let userDefaultsPath = UserDefaults.standard.string(forKey: "run_on_insert_script_path") {
            self.runAtInsertPathField.stringValue = URL(fileURLWithPath: userDefaultsPath).lastPathComponent
        }
        
        let runAtRemovalButton = NSButton(checkboxWithTitle: "Run Script On Removal", target: Any?.self, action: #selector(runOnRemovalChange))
        runAtRemovalButton.frame = NSRect(x: 185, y: 70, width: 200, height: 25)
        if UserDefaults.standard.bool(forKey: "run_on_removal") {
            runAtRemovalButton.state = .on
        }
        let isRunRemovalForced = CFPreferencesAppValueIsForced("run_on_removal" as CFString, appBundleID as CFString)
        if isRunRemovalForced {
            runAtRemovalButton.isEnabled = false
        }
        self.runAtRemovalPathField = NSTextField(frame: NSRect(x: 185, y: 50, width: 125, height: 20))
        self.runAtRemovalPathField.drawsBackground = true
        self.runAtRemovalPathField.isSelectable = false
        self.runAtRemovalPathField.isBordered = true
        if let userDefaultsPath = UserDefaults.standard.string(forKey: "run_on_removal_script_path") {
            self.runAtRemovalPathField.stringValue = URL(fileURLWithPath: userDefaultsPath).lastPathComponent
        }
        
        let isRunRemovalPathForced = CFPreferencesAppValueIsForced("run_on_removal_script_path" as CFString, appBundleID as CFString)
        let isRunInsertPathForced = CFPreferencesAppValueIsForced("run_on_insert_script_path" as CFString, appBundleID as CFString)
        
        let chooseInsertButton = NSButton(title: "Choose…", target: self, action: #selector(chooseInsertScript))
        chooseInsertButton.frame = NSRect(x: 315, y: 100, width: 75, height: 20)
        if isRunInsertPathForced {
            chooseInsertButton.isEnabled = false
        }
        let chooseRemovalButton = NSButton(title: "Choose…", target: self, action: #selector(chooseRemovalScript))
        chooseRemovalButton.frame = NSRect(x: 315, y: 50, width: 75, height: 20)
        if isRunRemovalPathForced {
            chooseRemovalButton.isEnabled = false
        }
        let updateButton = NSButton(title: "Check for Updates", target: Any?.self, action: #selector(updateCheck))
        updateButton.frame = NSRect(x: 215, y: 10, width: 150, height: 30)
        
        let isForced = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
        if UserDefaults.standard.bool(forKey: "disableUpdates") && isForced {
            updateButton.isEnabled = false
        }
        let infoTextView = NSTextView(frame: NSRect(x: 168, y: 145, width: 240, height: 25))
        infoTextView.textContainerInset = NSSize(width: 10, height: 10)
        infoTextView.isEditable = false
        infoTextView.isSelectable = true
        infoTextView.drawsBackground = false
        guard let versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {return}
        let title = "SC Menu"
        
        let version = "Version: \(versionText)"
        let titleTextView = NSTextField(frame: NSRect(x: 180, y: 170, width: 100, height: 40))
        
        titleTextView.font = NSFont.boldSystemFont(ofSize: 16)
        titleTextView.isBordered = false
        titleTextView.isBezeled = false
        titleTextView.isEditable = false
        titleTextView.drawsBackground = false
        titleTextView.stringValue = title
        
        let versionTextView = NSTextField(frame: NSRect(x: 180, y: 150, width: 100, height: 40))
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
        infoTextView.textStorage?.setAttributedString(infoAttributedString)
        
        let appIcon = NSImageView(frame:NSRect(x: 265, y:170, width: 40, height: 40))
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
        view.addSubview(notificationsButton)
        view.addSubview(updateButton)
        view.addSubview(runAtInsertPathField)
        view.addSubview(runAtInsertButton)
        view.addSubview(runAtRemovalPathField)
        view.addSubview(runAtRemovalButton)
        view.addSubview(chooseInsertButton)
        view.addSubview(chooseRemovalButton)
        
        if let existingInsertPath = UserDefaults.standard.string(forKey: "run_on_insert_path") {
            self.runAtInsertScriptPath = existingInsertPath
        }
        if let existingRemovalPath = UserDefaults.standard.string(forKey: "run_on_removal_path") {
            self.runAtRemovalScriptPath = existingRemovalPath
        }
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
    
    /// Toggle whether SC Menu should show local user notifications.
    /// Persisted via `UserDefaults` under `show_notifications`.
    @objc func notificationChange(_ sender: NSButton){
        if sender.intValue == 1 {
            UserDefaults.standard.set(true, forKey: "show_notifications")
        }else {
            UserDefaults.standard.set(false, forKey: "show_notifications")
        }
        
    }
    
    /// Switch between colorful and black & white status bar icons.
    /// Writes `icon_mode` in `UserDefaults` and informs the delegate to refresh the icon.
    @objc func changeIcon(_ sender: NSButton) {
        //use UserDefaults
        
        if sender.title == "Black and White" {
            UserDefaults.standard.set("bw", forKey: "icon_mode")
            os_log("B&W Icon selected", log: prefsLog, type: .default)
            self.delegate?.didReceivePrefUpdate()
            
        }
        
        if sender.title == "Colorful" {
            UserDefaults.standard.set("colorful", forKey: "icon_mode")
            os_log("Colorful Icon selected", log: prefsLog, type: .default)
            self.delegate?.didReceivePrefUpdate()
        }
    }
    
    /// Enable/disable running a custom script when a smartcard is removed.
    /// Stores a boolean flag in `UserDefaults` under `run_on_removal`.
    @objc func runOnRemovalChange(_ sender: NSButton) {
        if sender.intValue == 1 {
            
            UserDefaults.standard.set(true, forKey: "run_on_removal")
        }else {
            UserDefaults.standard.removeObject(forKey: "run_on_removal")
        }
    }
    
    /// Enable/disable running a custom script when a smartcard is inserted.
    /// Stores a boolean flag in `UserDefaults` under `run_on_insert`.
    @objc func runOnInsertChange(_ sender: NSButton) {
        if sender.intValue == 1 {
            UserDefaults.standard.set(true, forKey: "run_on_insert")
        } else {
            UserDefaults.standard.removeObject(forKey: "run_on_insert")
        }
    }
    
    /// Manually trigger an update check against GitHub Releases and present the result.
    @objc func updateCheck(_ sender: NSButton) {
        os_log("Update button pressed", log: prefsLog, type: .default)
        let updater = UpdateCheck()
        Task {
            switch await updater.check() {
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
        
    }
    
    
    /// Add or remove SC Menu as a login item using `SMAppService.mainApp`.
    /// Logs success/failure to the preferences log.
    @objc func loginItemChange(_ sender: NSButton) {
        if sender.intValue == 1 {
            do {
                try SMAppService.mainApp.register()
                os_log("SC Menu set to launch at login", log: self.prefsLog, type: .default)
            } catch {
                os_log("SMApp Service register error %{public}s", log: self.prefsLog, type: .error, error.localizedDescription)
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                os_log("SC Menu removed from login items", log: self.prefsLog, type: .default)
            } catch {
                os_log("SMApp Service unregister error %{public}s", log: self.prefsLog, type: .default, error.localizedDescription)
            }
        }
    }
    
    /// Present an open panel to select a script to run on insert. Stores the full path
    /// in `UserDefaults` under `run_on_insert_script_path` and updates the label.
    @objc private func chooseInsertScript(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.title = "Choose a Script to Run on Insert"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["sh", "command", "py", "zsh", "bash", "applescript", "scpt"].compactMap { UTType(filenameExtension: $0) }

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            self.runAtInsertScriptPath = path
            UserDefaults.standard.set(path, forKey: "run_on_insert_script_path")
            os_log("Selected insert script: %{public}s", log: self.prefsLog, type: .default, path)
        }
    }

    /// Present an open panel to select a script to run on removal. Stores the full path
    /// in `UserDefaults` under `run_on_removal_script_path` and updates the label.
    @objc private func chooseRemovalScript(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.title = "Choose a Script to Run on Removal"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["sh", "command", "py", "zsh", "bash", "applescript", "scpt"].compactMap { UTType(filenameExtension: $0) }

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            self.runAtRemovalScriptPath = path
            UserDefaults.standard.set(path, forKey: "run_on_removal_script_path")
            os_log("Selected removal script: %{public}s", log: self.prefsLog, type: .default, path)
        }
    }
    
}

