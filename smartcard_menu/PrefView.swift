//
//  PrefView.swift
//  SC Menu
//
//  Created by Bob Gendler on 10/11/26.
//

import SwiftUI
import ServiceManagement
import os
import UserNotifications

@MainActor
protocol PreferencesDelegate: AnyObject {
    func preferencesDidChange()
}

struct PrefView: View {
    
    @AppStorage("run_on_insert_script_path") var run_on_insert_script_path: String?
    @AppStorage("run_on_insert") var run_on_insert: Bool = false
    
    @AppStorage("run_on_removal_script_path") var run_on_removal_script_path: String?
    @AppStorage("run_on_removal") var run_on_removal: Bool = false
    
    @AppStorage("disableUpdates") var disableUpdates: Bool = false
    
    @AppStorage("icon_mode") var icon_mode: String = "colorful"
    @AppStorage("DaysToExpiration") var DaysToExpiration: Int = 30
    @AppStorage("inserted") var inserted: Bool = false
    
    @AppStorage("show_notifications") var show_notifications = false
    @AppStorage("showCardInsert") var showCardInsert: Bool = true
    @AppStorage("showCardRemoval") var showCardRemoval: Bool = true
    @AppStorage("showCertExpires") var showCertExpires: Bool = true
    @AppStorage("showCardExpires") var showCardExpires: Bool = true
    
    @State private var notificationButtonsDisabled = false
    @State private var forcedNotifications = false
    @State private var forcedInsert = false
    @State private var forcedRemoval = false
    @State private var forcedInsertRunPath = false
    @State private var forcedRemovalRunPath = false
    @State private var forcedUpdate = false
    
    @State private var launchAtLogin = true
    
    @State private var scriptOnInsert = ""
    @State private var scriptOnRemoval = ""
    
    @State private var fileInsertshow = false
    @State private var fileRemovalshow = false
    
    private let prefsLog = OSLog(subsystem: subsystem, category: "Preferences")
    
    weak var delegate: (any PreferencesDelegate)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Menu Icon")
                    .padding(.leading, 10)
                Picker(selection: $icon_mode, label: Text("")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 20) {
                            Image(nsImage: NSImage(named: "smartcard_out")!)
                            Image(nsImage: NSImage(named: "smartcard_in")!)
                        }
                        
                        Text("Colorful")
                    }
                    .tag("colorful")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 20) {
                            Image(nsImage: NSImage(named: "smartcard_out_bw")!)
                            Image(nsImage: NSImage(named: "smartcard_in_bw")!)
                        }
                        
                        Text("Black and White")
                    }
                    .tag("bw")
                    
                }.pickerStyle(.radioGroup)
                    .padding(.bottom, 5)
                    .onChange(of: icon_mode) {
                        delegate?.preferencesDidChange()
                    }
                
                Toggle(isOn: $show_notifications) {
                    Text("Show Notifications")
                }
                .toggleStyle(.checkbox)
                .padding(.leading, 8)
                .padding(.bottom, 3)
                .disabled(forcedNotifications)
                .onChange(of: show_notifications) {
                    if show_notifications {
                        notificationButtonsDisabled = false
                    } else {
                        notificationButtonsDisabled = true
                    }
                }
                VStack(alignment: .leading) {
                    Toggle(isOn: $showCardInsert) {
                        Text("Insert")
                    }
                    .toggleStyle(.checkbox)
                    .padding(.leading, 8)
                    .padding(.bottom, 3)
                    .disabled(notificationButtonsDisabled || forcedNotifications)
                    Toggle(isOn: $showCardRemoval) {
                        Text("Removal")
                    }
                    .toggleStyle(.checkbox)
                    .padding(.leading, 8)
                    .padding(.bottom, 3)
                    .disabled(notificationButtonsDisabled || forcedNotifications)
                    Toggle(isOn: $showCertExpires) {
                        Text("Certificate Expiration")
                    }
                    .toggleStyle(.checkbox)
                    .padding(.leading, 8)
                    .padding(.bottom, 3)
                    .disabled(notificationButtonsDisabled || forcedNotifications)
                    Toggle(isOn: $showCardExpires) {
                        Text("Card Expiration")
                    }
                    .toggleStyle(.checkbox)
                    .padding(.leading, 8)
                    .padding(.bottom, 3)
                    .disabled(notificationButtonsDisabled || forcedNotifications)
                }
                .padding(.leading, 20)
                
                
            }
            .frame(alignment: .leading)
            .padding(.top, 10)
            Group{
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("SC Menu")
                                .fontWeight(.bold)
                                .font(.system(size: 16))
                                .frame(alignment: .leading)
                            Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0")")
                            
                        }
                        Image(nsImage: NSImage(named: "new_icon")!)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        
                    }
                    Text("[https://github.com/boberito/sc_menu](https://github.com/boberito/sc_menu)")
                        .font(.custom("Helvetica", size: 12))
                        .underline()
                        .padding(.top, -5)
                    
                    Toggle(isOn: Binding(
                        get: { launchAtLogin },
                        set: { enabled in
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                os_log(
                                    "Login item change failed: %{public}@",
                                    log: prefsLog,
                                    type: .error,
                                    error.localizedDescription
                                )
                            }
                            
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    )) {
                        Text("Launch SC Menu at Login")
                    }
                    .toggleStyle(.checkbox)
                    .padding(.bottom, 5)
                    .padding(.top, 5)
                    
                    Toggle(isOn: $run_on_insert){
                        Text("Run Script on Insert")
                    }
                    .disabled(forcedInsert)
                    HStack {
                        TextField("", text: $scriptOnInsert)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120, height: 20, alignment: .leading)
                            .allowsHitTesting(false)
                            .focusable(false)
                        
                        Button("Choose..."){
                            fileInsertshow = true
                        }
                        .disabled(forcedInsertRunPath)
                        .fileImporter(
                            isPresented: $fileInsertshow,
                            allowedContentTypes: [.shellScript, .appleScript, .osaScript, .javaScript, .perlScript, .phpScript, .script, .rubyScript, .pythonScript, .osaScriptBundle, .applicationBundle, .application, .executable],
                        ) { result in
                            switch result {
                            case .success(let openUrl):
                                
                                run_on_insert_script_path = openUrl.path(percentEncoded: false)
                                if let insertScript = run_on_insert_script_path {
                                    scriptOnInsert = URL(fileURLWithPath: insertScript).lastPathComponent
                                }
                                
                            case .failure(let error):
                                os_log("Import failed: %{public}@", log: prefsLog, type: .default, error.localizedDescription)
                            }
                            fileInsertshow = false
                        }
                        .fileDialogMessage("Choose a Script to Run on Insert")
                        .fileDialogConfirmationLabel("Open")
                    }
                    .padding(.top, -5)
                    
                    
                    Toggle(isOn: $run_on_removal){
                        Text("Run Script on Removal")
                    }
                    .disabled(forcedRemoval)
                    HStack {
                        TextField("", text: $scriptOnRemoval)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120, height: 20)
                            .allowsHitTesting(false)
                            .focusable(false)
                        Button("Choose...") {
                            fileRemovalshow = true
                        }
                        .disabled(forcedRemovalRunPath)
                        .fileImporter(
                            isPresented: $fileRemovalshow,
                            allowedContentTypes: [.shellScript, .appleScript, .osaScript, .javaScript, .perlScript, .phpScript, .script, .rubyScript, .pythonScript, .osaScriptBundle, .applicationBundle, .application, .executable],
                        ) { result in
                            switch result {
                            case .success(let openUrl):
                                
                                run_on_removal_script_path = openUrl.path(percentEncoded: false)
                                if let removalScript = run_on_removal_script_path {
                                    scriptOnRemoval = URL(fileURLWithPath: removalScript).lastPathComponent
                                }
                                
                            case .failure(let error):
                                os_log("Import failed: %{public}@", log: prefsLog, type: .default, error.localizedDescription)
                            }
                            fileRemovalshow = false
                        }
                        .fileDialogMessage("Choose a Script to Run on Removal")
                        .fileDialogConfirmationLabel("Open")
                    }
                    .padding(.top, -5)
                    
                    Button("Check For Updates") {
                        os_log("Update button pressed", log: prefsLog, type: .default)
                        (NSApp.delegate as? AppDelegate)?.checkForUpdates(nil)
                    }
                    .padding(.top, 10)
                    .disabled(forcedUpdate && disableUpdates)
                }
            }
            .padding(.leading, -5)
        }
        .padding(10)
        .frame(width: 415, height: 300, alignment: .leading)
        .task {
            switch SMAppService.mainApp.status {
            case .enabled:
                launchAtLogin = true
            default:
                launchAtLogin = false
            }
            
            if let insertScript = run_on_insert_script_path {
                scriptOnInsert = URL(fileURLWithPath: insertScript).lastPathComponent
            }
            
            if let removalScript = run_on_removal_script_path {
                scriptOnRemoval = URL(fileURLWithPath: removalScript).lastPathComponent
            }
            let nc = UNUserNotificationCenter.current()
            let settings = await nc.notificationSettings()
            if settings.authorizationStatus != .authorized {
                show_notifications = false
                notificationButtonsDisabled = true
                if settings.authorizationStatus == .denied {
                    forcedNotifications = true
                    notificationButtonsDisabled = true
                }
            }
        }
        .onAppear() {
            guard let appBundleID = Bundle.main.bundleIdentifier else { return }
            forcedNotifications = CFPreferencesAppValueIsForced("show_notifications" as CFString, appBundleID as CFString)
            forcedInsert = CFPreferencesAppValueIsForced("run_on_insert" as CFString, appBundleID as CFString)
            forcedRemoval = CFPreferencesAppValueIsForced("run_on_removal" as CFString, appBundleID as CFString)
            forcedRemovalRunPath = CFPreferencesAppValueIsForced("run_on_removal_script_path" as CFString, appBundleID as CFString)
            forcedInsertRunPath = CFPreferencesAppValueIsForced("run_on_insert_script_path" as CFString, appBundleID as CFString)
            forcedUpdate = CFPreferencesAppValueIsForced("disableUpdates" as CFString, appBundleID as CFString)
        }
    }
    
}

#Preview {
    PrefView()
}
