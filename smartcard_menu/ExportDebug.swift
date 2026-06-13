//
//  Untitled.swift
//  SC Menu
//
//  Created by Bob Gendler on 6/13/26.
//
import Foundation
import CryptoTokenKit
import OSLog


class exportDebug {
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let os_ver = ProcessInfo.processInfo.operatingSystemVersionString
    private var myTKWatcher: TKTokenWatcher? = nil
    
    func export(TkID: String) {
        if let slotName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName, let driverName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.driverName {
            let pivCard = PIVCard(token: TkID, slotName: slotName, driverName: driverName)
            guard let atrString = pivCard.atrString else { return }
        }
    }
    
}
