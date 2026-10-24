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
    
    @State private var iconSelected = ""
    @State private var showNotifications = true
    @State private var launchAtLogin = true
    @State private var runOnInsert = false
    @State private var runOnRemovable = false
    @State private var showCertificateInsert = true
    @State private var showCertificateRemoval = true
    @State private var showCardExpiration = true
    @State private var showCertExpiration = true
    
    @AppStorage("run_on_insert_script_path") var run_on_insert_script_path: String?
    @AppStorage("run_on_insert") var run_on_insert: Bool = false
    
    @AppStorage("run_on_removal_script_path") var run_on_removal_script_path: String?
    @AppStorage("run_on_removal") var run_on_removal: Bool = false
    
    @AppStorage("disableUpdates") var disableUpdates: Bool = false
    
    @AppStorage("icon_mode") var icon_mode: String = "colorful"
    @AppStorage("DaysToExpiration") var DaysToExpiration: Int = 30
    @AppStorage("inserted") var inserted: Bool = false
    @AppStorage("afterFirstLaunch") var afterFirstLaunch: Bool = false
    
    @AppStorage("show_notifications") var show_notifications: Bool?
    @AppStorage("showCardInsert") var showCardInsert: Bool = true
    @AppStorage("showCardRemoval") var showCardRemoval: Bool = true
    @AppStorage("showCertExpires") var showCertExpires: Bool = true
    @AppStorage("showCardExpires") var showCardExpires: Bool = true
    
    @State private var notificationButtonsDisabled = false
    
    @State private var scriptOnInsert = ""
    @State private var scriptOnRemoval = ""
    
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
                
                Toggle(isOn: Binding(get: { show_notifications ?? false}, set: {show_notifications = $0})) {
                    Text("Show Notifications")
                }
                    .toggleStyle(.checkbox)
                    .padding(.leading, 8)
                    .padding(.bottom, 3)
                    
                    .onChange(of: show_notifications) {
                        if let show_notifications = show_notifications, !show_notifications {
                            notificationButtonsDisabled = true
                        } else {
                            notificationButtonsDisabled = false
                        }
                        
                        
                                                
                        
                    }
                VStack(alignment: .leading) {
                    Toggle(isOn: $showCardInsert) {
                        Text("Insert")
                    }
                        .toggleStyle(.checkbox)
                        .padding(.leading, 8)
                        .padding(.bottom, 3)
                        .disabled(notificationButtonsDisabled)
                    Toggle(isOn: $showCardRemoval) {
                        Text("Removal")
                    }
                        .toggleStyle(.checkbox)
                        .padding(.leading, 8)
                        .padding(.bottom, 3)
                        .disabled(notificationButtonsDisabled)
                    Toggle(isOn: $showCertExpires) {
                        Text("Certificate Expiration")
                    }
                        .toggleStyle(.checkbox)
                        .padding(.leading, 8)
                        .padding(.bottom, 3)
                        .disabled(notificationButtonsDisabled)
                    Toggle(isOn: $showCardExpires) {
                        Text("Card Expiration")
                    }
                        .toggleStyle(.checkbox)
                        .padding(.leading, 8)
                        .padding(.bottom, 3)
                        .disabled(notificationButtonsDisabled)
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
                    Text("https://github.com/boberito/sc_menu")
                        .font(.custom("Helvetica", size: 12))
                        .underline()
                        .padding(.top, -5)
                    
                    Toggle(isOn: $launchAtLogin) {
                        Text("Launch SC Menu at Login")
                    }
                    .toggleStyle(.checkbox)
                    .padding(.bottom, 5)
                    .padding(.top, 5)
                    
                    Toggle(isOn: $runOnInsert){
                        Text("Run Script on Insert")
                    }
                    HStack {
                        TextField("", text: $scriptOnInsert)
                            .textFieldStyle(.roundedBorder)
//                            .padding(.leading, -1)
                            .frame(width: 120, height: 20, alignment: .leading)
                            
                        Button("Choose..."){
                            
                        }
                    }
                    .padding(.top, -5)
                    Toggle(isOn: $runOnRemovable){
                        Text("Run Script on Removal")
                    }
                    HStack {
                        TextField("", text: $scriptOnRemoval)
                            .textFieldStyle(.roundedBorder)
//                            .padding(.leading, -1)
                            .frame(width: 120, height: 20)
                        Button("Choose...") {
                            
                        }
                    }
                    .padding(.top, -5)
                    Button("Check For Updates") {
                        
                    }
                    
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
            if settings.authorizationStatus == .authorized {
                show_notifications = true
            } else {
                show_notifications = false
                
            }
        }
    }
    
}

#Preview {
    PrefView()
}
