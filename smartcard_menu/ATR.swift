//
//  ATR.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/29/24.
//

import Foundation
import CryptoTokenKit

/// Convenience wrapper to fetch the ATR string for a token/slot using CryptoTokenKit.
/// The ATR is presented in hex for external debugging sites.
class PIVCard {
    let token: String
    let slotName: String?
    let driverName: String?
    var atrString: String?
    
    init(token: String, slotName: String?, driverName: String?) {
        self.token = token
        self.slotName = slotName
        self.driverName = driverName
        
        getATR()
    }
    
    /// Resolve the slot by name and capture its ATR bytes as a hex string.
    func getATR() {
        
        guard let slotName = slotName else { return }
        let sm = TKSmartCardSlotManager()
        sm.getSlot(withName: slotName, reply: { slot in
            if let atr = slot?.atr {
                self.atrString = atr.bytes.hexEncodedString()
                
            }
        })
    }
}

/// MARK: - Utilities
extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
