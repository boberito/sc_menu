//
//  ViewCerts.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/20/24.
//
import Foundation
import UserNotifications
import os

struct identityList {
    var cn: String
    var pubKeyHash: String
    var identity: SecIdentity
    var oids: String
    var token: Bool
    var keychain: Int
    var keychainRef : SecKeychain?
    var principal : String?
    var friendlyName: String?
    var ca: String?
    var caOrg: String?
}

class ViewCerts{
    var certErr: OSStatus
    
    init() {
        certErr = 0
    }
    func getIdentity(pivToken: String) -> Dictionary<String,SecIdentity>? {
        var myCN: CFString? = nil
        var searchResults: AnyObject? = nil
        var myCert: SecCertificate? = nil
        var certDict = [String:SecIdentity]()
        
        let getquery: [String: Any] = [
            kSecAttrAccessGroup as String:  kSecAttrAccessGroupToken,
            kSecClass as String: kSecClassIdentity,
            kSecReturnAttributes as String: true as AnyObject,
            kSecAttrTokenID as String: pivToken,
            kSecReturnRef as String: true as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]
        
        if getquery.count > 0 {
            
            let status = SecItemCopyMatching(getquery as CFDictionary, &searchResults)
            if status != 0 {
                
                return nil
            }
            let existingCerts = searchResults as! CFArray as Array
            
            for cert in existingCerts{
                
                certErr = SecIdentityCopyCertificate(cert["v_Ref"] as! SecIdentity, &myCert)
                
                if certErr != 0 {
                    continue
                }
                guard let myCert else { continue }
                certErr = SecCertificateCopyCommonName(myCert, &myCN)
                let labelString = cert["labl"] as? String ?? "no label"
                certDict.updateValue(cert["v_Ref"] as! SecIdentity, forKey: labelString)
            }
            
            return certDict
            
        }
        
        return nil
        
    }
    
    func readExpiration(pivToken: String) async -> Bool?{
        let certLog = OSLog(subsystem: subsystem, category: "Certificate")
        let appLog = OSLog(subsystem: subsystem, category: "General")
        
        let nc = UNUserNotificationCenter.current()
        var searchResults: AnyObject? = nil
        var myCert: SecCertificate? = nil
        
        let getquery: [String: Any] = [
            kSecAttrAccessGroup as String:  kSecAttrAccessGroupToken,
            kSecClass as String: kSecClassIdentity,
            kSecReturnAttributes as String: true as AnyObject,
            kSecAttrTokenID as String: pivToken,
            kSecReturnRef as String: true as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]
        
        if getquery.count > 0 {
            
            let status = SecItemCopyMatching(getquery as CFDictionary, &searchResults)
            if status != 0 {                
                return
            }
            let existingCerts = searchResults as! CFArray as Array
            
            for cert in existingCerts{
                
                certErr = SecIdentityCopyCertificate(cert["v_Ref"] as! SecIdentity, &myCert)
                
                if certErr != 0 {
                    continue
                }
                guard let myCert else { continue }
                let keys = [kSecOIDX509V1ValidityNotAfter]
                let expiration = SecCertificateCopyValues(myCert, keys as CFArray, nil) as? [CFString: Any]
                if let expiration = expiration,
                   let notAfterDict = expiration[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
                   let notAfterValue = notAfterDict[kSecPropertyKeyValue] {
                    
                    // Convert CFNumber to TimeInterval (seconds since reference date)
                    guard let timeInterval = notAfterValue as? Double else { continue }
                    let expirationDate = Date(timeIntervalSinceReferenceDate: timeInterval)
                    guard let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date.now) else { continue }
                   
                    if expirationDate <= thirtyDaysFromNow && expirationDate >= Date.now {
                        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date.now, to: expirationDate).day ?? 0
                        os_log("Certificate on the smartcard is expiring within {public}s days", log: certLog, type: .info, daysUntilExpiration)
                        let settings = await nc.notificationSettings()
                        if (settings.authorizationStatus == .authorized) ||
                            (settings.authorizationStatus == .provisional)  {
                            let content = UNMutableNotificationContent()
                            
                            
                            content.title = "Smartcard Certificate Expiring"
                            content.body = "A smartcard certificate is expiring in \(daysUntilExpiration) days"
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                            
                            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                            do {
                                try await nc.add(request)
                            } catch {
                                os_log("Notification error {public}s", log: appLog, type: .default, error.localizedDescription)
                            }
                        }
                        
//                        return true
                    } else if expirationDate < Date.now {
                        let settings = await nc.notificationSettings()
                        if (settings.authorizationStatus == .authorized) ||
                            (settings.authorizationStatus == .provisional)  {
                            let content = UNMutableNotificationContent()
                            content.title = "Certificate EXPIRED"
                            content.body = "A Certificate on the Smartcard is EXPIRED"
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                            
                            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                            
                            do {
                                try await nc.add(request)
                            } catch {
                                os_log("Notification error {public}s", log: appLog, type: .default, error.localizedDescription)
                            }
                        }
//                        return nil
                    }
                }
                
            }
            
            
            
        }
//     return nil
    }
}
