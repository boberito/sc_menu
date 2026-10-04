//
//  Untitled.swift
//  SC Menu
//
//  Created by Bob Gendler on 6/13/26.
//
import Foundation
import CryptoTokenKit
import OSLog
import OpenDirectory
import Security

struct SmartCard {
    var PivToken: String?
    var Reader: String?
    var Driver: String?
    var Cert: [CertInfo?]
    var ATR: String?
    
    
}

struct CertInfo {
    var label: String?
    var hash: String?
}

class ExportDebug {
    
    var pairedIdentities = [String()]
    var mappedIdentities = [String()]
    
    var smartcards: [SmartCard] = []
    
    
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let os_ver = ProcessInfo.processInfo.operatingSystemVersionString
    private var myTKWatcher: TKTokenWatcher? = nil
    let currentConsoleUserName: String = NSUserName()
    let uid: String = String(getuid())
    
    private func getATR(slotName: String,manager: TKSmartCardSlotManager) async -> String? {
        await withCheckedContinuation { continuation in
            manager.getSlot(withName: slotName) { slot in
                let atrString = slot?.atr?.bytes.hexEncodedString()
                continuation.resume(returning: atrString)
            }
        }
    }
    
    
    private func queryKeychain(pivToken: String) -> [CertInfo]? {
        var certInfo: [CertInfo] = []
        let getquery: [String: Any] = [
            kSecAttrAccessGroup as String:  kSecAttrAccessGroupToken,
            kSecClass as String: kSecClassIdentity,
            kSecReturnAttributes as String: true as AnyObject,
            kSecAttrTokenID as String: pivToken,
            kSecReturnRef as String: true as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]
        var searchResults: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &searchResults)
        guard status == errSecSuccess, let rawResults = searchResults else {
            print("Smartcard/Keychain Error or Issue")
            return nil
        }
        
        // Transfer ownership of the CFArray to ARC and work with a Swift array
        guard let existingCerts = rawResults as? [[AnyHashable: Any]] else { return nil }
        
        for certDictAny in existingCerts {
            let label = certDictAny[kSecAttrLabel] as? String ?? "untitled"
            if let hash = certDictAny[kSecAttrPublicKeyHash] as? Data {
                
                certInfo.append(CertInfo(label: label, hash: hash.hexEncodedString().uppercased()))
            }
        }
        return certInfo        
    }
    
    private func pivStuff () async {
        
        var slotName: String?
        var driverName: String?
        var tokenID: String?
        
        myTKWatcher = TKTokenWatcher()
        guard let tokenIDs = myTKWatcher?.tokenIDs else {
            return
        }
        for TkID in tokenIDs {
            if TkID.contains("com.apple.setoken") || TkID.contains("com.apple.ctkcard") { continue }
            slotName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.slotName
            driverName = myTKWatcher?.tokenInfo(forTokenID: TkID)?.driverName
            tokenID = myTKWatcher?.tokenInfo(forTokenID: TkID)?.tokenID
            print("")
            print("PIV Token Identity: \(tokenID ?? "")")
            print("Smartcard Reader: \(slotName ?? "")")
            print("Smartcard Driver: \(driverName ?? "")")
            
            var smartcard = SmartCard(
                PivToken: tokenID,
                Reader: slotName,
                Driver: driverName,
                Cert: [],
                ATR: nil
            )
            guard let slotName = slotName else { continue }
            let manager = TKSmartCardSlotManager()
            
            if let atrString = await getATR(
                slotName: slotName,
                manager: manager
            ) {
                smartcard.ATR = atrString
            } else {
                print("ATR unavailable for \(slotName)")
            }
            
            if let tokenID = tokenID {
                
                if let certQuery = queryKeychain(pivToken: tokenID) {
                    smartcard.Cert = certQuery
                }
            }
            smartcards.append(smartcard)
        }
    }
    
    func export() async {
        
        print("SC Menu App Version: \(appVersion ?? "")")
        print("macOS \(os_ver)")
        
        getCurrentConsoleUserRecord()
        
        await pivStuff()
        
        print("Current User: \(currentConsoleUserName)")
        print("Current UID: \(uid)")
        for mappedIdentity in mappedIdentities {
            if mappedIdentity == "" {
                continue
            }
            print("Mapped Identity: \(mappedIdentity)")
        }
        for pairedIdentity in pairedIdentities {
            if pairedIdentity == "" {
                continue
            }
            print("Paired Identity: \(pairedIdentity)")
        }
        if smartcards.count > 0 {
            for smartcard in smartcards {
                print(smartcard.PivToken ?? "")
                print(smartcard.Reader ?? "")
                print(smartcard.Driver ?? "")
                for cert in smartcard.Cert {
                    if let hash = cert?.hash, let label = cert?.label {
                        if mappedIdentities.contains(hash) {
                            print("\(label): \(hash) - Mapped")
                        }
                        else if pairedIdentities.contains(hash) {
                            print("\(label): \(hash) - Paired")
                        }
                        else {
                            print("\(label): \(hash)")
                        }
                    }
                }
            }
        }
    }
    
    
    
    private func getCurrentConsoleUserRecord(){
        
        let session = ODSession.default()
        var records = [ODRecord]()
        do {
            //let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))
            let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let query = try ODQuery.init(node: node,
                                         forRecordTypes: kODRecordTypeUsers,
                                         attribute: kODAttributeTypeRecordName,
                                         matchType: UInt32(kODMatchEqualTo),
                                         queryValues: currentConsoleUserName,
                                         returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
            records = try query.resultsAllowingPartial(false) as! [ODRecord]
            
            for record in records {
                // Request a specific native attribute by name
                let details = try record.recordDetails(forAttributes: ["dsAttrTypeNative:authentication_authority"])
                
                // details is a dictionary [AnyHashable: Any]; extract and print neatly
                if let dict = details as? [String: Any], let auth = dict["dsAttrTypeNative:authentication_authority"] {
                    let items = String(describing: auth).split(separator: ",")
                    for item in items {
                        if item.contains("amidentity") {
                            let mapped = item.split(separator: ";")[2].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: ")", with: "")
                            mappedIdentities.append(mapped)
                        }
                        if item.contains("tokenidentity") {
                            let paired = item.split(separator: ";")[2].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: ")", with: "")
                            pairedIdentities.append(paired)
                            
                        }
                    }
                    
                } else {
                    Swift.print("authentication_authority not found")
                }
            }
            
        } catch {
            Swift.print("\(error.localizedDescription)")
        }
    }
    
}
