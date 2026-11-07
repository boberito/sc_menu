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

/// Collects one token's reader, driver, certificate metadata, and answer-to-reset (ATR) bytes.
struct SmartCard {
    var PivToken: String?
    var Reader: String?
    var Driver: String?
    var Cert: [CertInfo?]
    var ATR: String?
    
    
}

/// Pairs a certificate label with its hexadecimal public-key hash for identity matching.
struct CertInfo {
    var label: String?
    var hash: String?
}

/// Collects local account and smartcard diagnostics for the command-line info report.
class ExportDebug {
    
    var pairedIdentities = [String()]
    var mappedIdentities = [String()]
    
    var smartcards: [SmartCard] = []
    
    
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let os_ver = ProcessInfo.processInfo.operatingSystemVersionString
    private var myTKWatcher: TKTokenWatcher? = nil
    let currentConsoleUserName: String = NSUserName()
    let uid: String = String(getuid())
    
    /// Bridges the slot lookup callback to async and returns its ATR as lowercase hex, or nil if unavailable.
    private func getATR(slotName: String,manager: TKSmartCardSlotManager) async -> String? {
        // Resume exactly once when CryptoTokenKit finishes resolving the reader slot.
        await withCheckedContinuation { continuation in
            manager.getSlot(withName: slotName) { slot in
                let atrString = slot?.atr?.bytes.hexEncodedString()
                continuation.resume(returning: atrString)
            }
        }
    }
    
    
    /// Returns labels and uppercase public-key hashes for identities on the requested token.
    /// Returns nil if the keychain query fails or its results cannot be decoded.
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
    
    /// Enumerates tokens, skips the built-in setoken and ctkcard identifiers, and prints reader details.
    /// Appends each reader's ATR and certificate metadata to `smartcards` for the final report.
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
            print("\u{001B}[1mPIV Token Identity:\u{001B}[0m \(tokenID ?? "")")
            print("\u{001B}[1mSmartcard Reader:\u{001B}[0m \(slotName ?? "")")
            print("\u{001B}[1mSmartcard Driver:\u{001B}[0m \(driverName ?? "")")
            print("")
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
    
    /// Prints app, OS, user, and token diagnostics to standard output.
    /// Matches certificate public-key hashes against the account's mapped and paired identities.
    func export() async {
        print("------------")
        print("\u{001B}[1mSC Menu App Version:\u{001B}[0m \(appVersion ?? "")")
        print("macOS \(os_ver)")
        
        getCurrentConsoleUserRecord()
        
        await pivStuff()
        
        print("\u{001B}[1mCurrent User:\u{001B}[0m \(currentConsoleUserName)")
        print("\u{001B}[1mCurrent UID:\u{001B}[0m \(uid)")
        print("")
        for mappedIdentity in mappedIdentities {
            if mappedIdentity == "" {
                continue
            }
            print("\u{001B}[1mMapped Identity:\u{001B}[0m \(mappedIdentity)")
        }
        print("")
        for pairedIdentity in pairedIdentities {
            if pairedIdentity == "" {
                continue
            }
            print("\u{001B}[1mPaired Identity:\u{001B}[0m \(pairedIdentity)")
        }
        print("")
        if smartcards.count > 0 {
            for smartcard in smartcards {
                for cert in smartcard.Cert {
                    if let hash = cert?.hash, let label = cert?.label {
                        if mappedIdentities.contains(hash) {
                            print("\(label): \(hash) - \u{001B}[1mMapped\u{001B}[0m")
                        }
                        else if pairedIdentities.contains(hash) {
                            print("\(label): \(hash) - \u{001B}[1mPaired\u{001B}[0m")
                        }
                        else {
                            print("\(label): \(hash)")
                        }
                    }
                }
            }
        }
    }
    
    
    
    /// Queries the local directory record for `NSUserName()` and collects smartcard identity hashes.
    /// Authentication authority entries distinguish mapped (`amidentity`) from paired (`tokenidentity`) hashes.
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
                            mappedIdentities.append(mapped.trimmingCharacters(in: .newlines))
                        }
                        if item.contains("tokenidentity") {
                            let paired = item.split(separator: ";")[2].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: ")", with: "")
                            pairedIdentities.append(paired.trimmingCharacters(in: .newlines))
                            
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
