//
//  ViewCerts.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/20/24.
//
import Foundation
import UserNotifications
import os

/// A model describing a certificate/identity found in the keychain/token. Not all fields
/// are used by the UI today; kept for potential future enhancements.
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

/// Helper for discovering identities on a PIV token and reading certificate metadata such as
/// expiration. Provides a dictionary of `SecIdentity` objects keyed by their label.
class ViewCerts{
    var certErr: OSStatus

    init() {
        certErr = 0
    }
    /// Query the keychain for identities that belong to the specified token ID and return them as
    /// a label -> SecIdentity dictionary. Returns nil if none found or query fails.
    func getIdentity(pivToken: String) -> Dictionary<String,SecIdentity>? {

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
            // use CFTypeRef? for the out parameter
            var searchResults: CFTypeRef?
            let status = SecItemCopyMatching(getquery as CFDictionary, &searchResults)
            guard status == errSecSuccess, let rawResults = searchResults else { return nil }

            // Transfer ownership of the CFArray to ARC and work with a Swift array
            guard let existingCerts = rawResults as? [[AnyHashable: Any]] else { return nil }

            for certDictAny in existingCerts {
                // Extract the identity reference; Keychain returns CFTypeRef bridged as AnyObject
                guard let identityAny = certDictAny["v_Ref"] as AnyObject? else { continue }
                let identity = identityAny as! SecIdentity

                // SecIdentityCopyCertificate returns a retained SecCertificateRef in myCert
                var myCert: SecCertificate?
                certErr = SecIdentityCopyCertificate(identity, &myCert)
                guard certErr == errSecSuccess, let cert = myCert else { continue }

                var myCN: CFString?
                certErr = SecCertificateCopyCommonName(cert, &myCN)
                let labelString = certDictAny["labl"] as? String ?? "no label"
                certDict.updateValue(identity, forKey: labelString)
            }

            return certDict
        }

        return nil
    }

    /// Iterate identities on the token and post a local notification if any certificate is
    /// expired or expiring within 30 days.
    func readExpiration(pivToken: String) async {
        let certLog = OSLog(subsystem: subsystem, category: "Certificate")
        let appLog = OSLog(subsystem: subsystem, category: "General")
//        var myCert: SecCertificate?

        let getquery: [String: Any] = [
            kSecAttrAccessGroup as String:  kSecAttrAccessGroupToken,
            kSecClass as String: kSecClassIdentity,
            kSecReturnAttributes as String: true as AnyObject,
            kSecAttrTokenID as String: pivToken,
            kSecReturnRef as String: true as AnyObject,
            kSecMatchLimit as String : kSecMatchLimitAll as AnyObject
        ]

        if getquery.count > 0 {
            var searchResults: CFTypeRef?
            let status = SecItemCopyMatching(getquery as CFDictionary, &searchResults)
            guard status == errSecSuccess, let rawResults = searchResults else {
                return
            }

            // Transfer ownership of the CFArray to ARC
            guard let existingCerts = rawResults as? [[AnyHashable: Any]] else { return }

            for certAny in existingCerts {
                let identity = certAny["v_Ref"] as! SecIdentity

                var certRef: SecCertificate?
                certErr = SecIdentityCopyCertificate(identity, &certRef)
                guard certErr == errSecSuccess, let cert = certRef else { continue }


                // SecCertificateCopyValues returns a retained CFDictionary; bridge it to Swift
                let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
                var valuesRef: CFDictionary?
                valuesRef = SecCertificateCopyValues(cert, keys, nil)
                if let valuesRaw = valuesRef {
                    guard let values = valuesRaw as? [CFString: Any] else { return }
                    let expiration = values
                    
                       if let notAfterDict = expiration[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
                       let notAfterValue = notAfterDict[kSecPropertyKeyValue] {
                        // SecCertificateCopyValues returns CFDate or CFNumber depending on implementation.
                        // Handle common cases: CFDate -> Date, CFNumber/Double -> time interval since reference date.
                        var expirationDate: Date?
                           let cfDate = notAfterValue as! CFDate
                        if let date = notAfterValue as? Date {
                            expirationDate = date
                        
                            expirationDate = cfDate as Date
                        } else if let timeInterval = notAfterValue as? Double {
                            expirationDate = Date(timeIntervalSinceReferenceDate: timeInterval)
                        } else if let number = notAfterValue as? NSNumber {
                            expirationDate = Date(timeIntervalSinceReferenceDate: number.doubleValue)
                        }

                        if let expDate = expirationDate {
                            guard let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date.now) else { continue }

                            if expDate <= thirtyDaysFromNow && expDate >= Date.now {
                                let nc = UNUserNotificationCenter.current()
                                let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date.now, to: expDate).day ?? 0
                                os_log("Certificate on the smartcard is expiring within %{public}d days", log: certLog, type: .info, daysUntilExpiration)
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
                            } else if expDate < Date.now {
                                let nc = UNUserNotificationCenter.current()
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
                            }
                        }
                    }
                }
            }
        }
    }
}
