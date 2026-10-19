//
//  PrefView.swift
//  SC Menu
//
//  Created by Bob Gendler on 10/11/26.
//

import SwiftUI

struct PrefView: View {
    
    @State private var iconSelected = ""
    @State private var showNotifications = true
    @State private var launchAtLogin = true
    @State private var runOnInsert = false
    @State private var runOnRemovable = false
    
    @State private var scriptOnInsert = "insert.sh"
    @State private var scriptOnRemoval = "removal.sh"
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Menu Icon")
                    .padding(.leading, 10)
                Picker(selection: $iconSelected, label: Text("")) {
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
                                .tag("B&W")
                    
                }.pickerStyle(.radioGroup)
                    .padding(.bottom, 5)
                
                Toggle(isOn: $showNotifications) {
                    Text("Show Notifications")
                }
                    .toggleStyle(.checkbox)
                    .padding(.leading, 8)
                    .padding(.bottom, 3)
                Toggle(isOn: $launchAtLogin) {
                    Text("Launch SC Menu at Login")
                }.toggleStyle(.checkbox)
                    .padding(.leading, 8)
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
                    
                    Toggle(isOn: $runOnInsert){
                        Text("Run Script on Insert")
                    }
                    //                self.runAtRemovalPathField = NSTextField(frame: NSRect(x: 185, y: 50, width: 125, height: 20))
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
            .padding(.leading, -10)
        }
        .padding(10)
        .frame(width: 415, height: 225, alignment: .leading)
    }
}

#Preview {
    PrefView()
}
