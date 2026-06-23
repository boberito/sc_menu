//
//  Untitled.swift
//  SC Menu
//
//  Created by Bob Gendler on 6/13/26.
//
import Foundation
import CryptoTokenKit
import OSLog

final class ExportDebug {
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let os_ver = ProcessInfo.processInfo.operatingSystemVersionString
    private var myTKWatcher: TKTokenWatcher? = nil
    
    // Async helper to fetch a smart card slot by name using continuations
    private func getSlot(named slotName: String, using manager: TKSmartCardSlotManager) async -> TKSmartCardSlot? {
        await withCheckedContinuation { continuation in
            manager.getSlot(withName: slotName) { slot in
                continuation.resume(returning: slot)
            }
        }
    }
    
    func export() async {
        var slotName: String?
        var driverName: String?
        var tokenID: String?
        var atrString: String?
        
        func pivStuff () async {
            myTKWatcher = TKTokenWatcher()
            guard let tokenIDs = myTKWatcher?.tokenIDs else {
                return
            }
            for TkID in tokenIDs {
                slotName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName
                driverName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.driverName
                tokenID = myTKWatcher?.tokenInfo(forTokenID: TkID)?.tokenID
                    guard let slotName = slotName else { continue }
                    let sm = TKSmartCardSlotManager()
                    if let slot = await getSlot(named: slotName, using: sm), let atr = slot.atr {
                        atrString = atr.bytes.hexEncodedString()
                    }
            }
        }
        await pivStuff()
        print("SC Menu App Version: \(appVersion ?? "")")
        print(os_ver)
        print(slotName ?? "")
        print(tokenID ?? "")
        print(driverName ?? "")
        print(atrString ?? "")
                
       
    }
    
}

