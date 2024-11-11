//
//  ATR.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/29/24.
//

import Foundation
import CryptoTokenKit

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
    
    func getATR() {
        
        guard let slotName = slotName else { return }
        let sm = TKSmartCardSlotManager()
        sm.getSlot(withName: slotName, reply: { slot in
            if let atr = slot?.atr {
                //                print(atr.bytes.hexEncodedString())
                self.atrString = atr.bytes.hexEncodedString()
                
            }
        })
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
