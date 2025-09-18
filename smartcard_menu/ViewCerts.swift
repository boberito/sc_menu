//
//  ViewCerts.swift
//  SC Menu
//
//  Created by Gendler, Bob (Fed) on 2/20/24.
//
import Foundation

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
//        print(pivToken)
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
                certErr = SecCertificateCopyCommonName(myCert!, &myCN)
                let labelString = cert["labl"] as? String ?? "no label"
                certDict.updateValue(cert["v_Ref"] as! SecIdentity, forKey: labelString)
            }
            
            return certDict
            
        }
        
        return nil
        
    }
}
