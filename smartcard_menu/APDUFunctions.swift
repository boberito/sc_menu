//
//  APDUFunctions.swift
//  SC Menu
//
//  Created by Bob Gendler on 11/1/24.
//

import Cocoa
import CryptoTokenKit
import OSLog

struct CardHolderInfo {
    var imagePath: String? = nil
    var name: String? = nil
    var employeeAffiliation: String? = nil
    var organization: String? = nil
    var expirationDate: String? = nil
    var cardSerialNumber: String? = nil
    var issueIdentifier: String? = nil
    var CCCData: CardholderCapabilityContainer? = nil
    var ac: String? = nil
    var sc: String? = nil
    var cn: String? = nil
    var cs: String? = nil
    var individualCredentail: String? = nil
    var personID: String? = nil
    var orgCategory2: String? = nil
    var orgID: String? = nil
    var PersonCategory2: String? = nil
    var guid: String? = nil
    var expiryDate: String? = nil
}

struct CardholderCapabilityContainer {
    var version: String
    var features: [String]
    var biometricSupport: Bool
    var secureMessaging: Bool
    // Add more fields as needed
}

protocol APDUDelgate {
    func didReceiveUpdate(cardInfo: CardHolderInfo)
    func pinFailed(slotName: String, attempts: Int)
}

class smartCardAPDU {
    
    var slotNameString = ""
    private let apduLog = OSLog(subsystem: subsystem, category: "APDUFunctions")
    var delegate: APDUDelgate?
    let SELECT_PIV_APPLICATION: [UInt8] = [0x00, 0xA4, 0x04, 0x00, 0x09, 0xA0, 0x00, 0x00, 0x03, 0x08, 0x00, 0x00, 0x10, 0x00]
    let GET_FACIAL_IMAGE: [UInt8] = [0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x08, 0x00]
    let GET_CARDHOLDER_NAME: [UInt8] = [0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x09, 0x00]
    let GET_CARD_CAPABILITY_CONTAINER: [UInt8] = [0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x07, 0x00]
    let GET_CARD_HOLDER_UNIQUE_IDENTIFIER: [UInt8] = [0x00, 0xCB, 0x3F, 0xFF, 0x05, 0x5C, 0x03, 0x5F, 0xC1, 0x02, 0x00]
    var smartCard: TKSmartCard?
    let tempPath = NSTemporaryDirectory()
    
    let logPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs/smartcard_apdu.log")
    let debugMode = UserDefaults.standard.bool(forKey: "debugMode")
    
    
    
    var cardHolderInfo = CardHolderInfo(
        imagePath: nil,
        name: nil,
        employeeAffiliation: nil,
        organization: nil,
        expirationDate: nil,
        cardSerialNumber: nil,
        issueIdentifier: nil,
        CCCData: nil,
        ac: nil,
        sc: nil,
        cn: nil,
        cs: nil,
        individualCredentail: nil,
        personID: nil,
        orgCategory2: nil,
        orgID: nil,
        PersonCategory2: nil,
        guid: nil,
        expiryDate: nil
    )
    
    
    func getBER_TLV(data: [UInt8], offset: Int = 0) -> (UInt8, [UInt8], Int)? {
        guard offset < data.count else {
            os_log("Offset out of range", log: self.apduLog, type: .error)
            return nil
        }
        let tlvType = data[offset]
        
        var tlvLength: Int
        var tlvValue: [UInt8]
        var nextTlv: Int
        
        if data[offset + 1] == 0x81 {
            // Length is encoded in 1 byte (0x81 format)
            tlvLength = Int(data[offset + 2])
            tlvValue = Array(data[(offset + 3)..<(offset + 3 + tlvLength)])
            nextTlv = tlvLength + 3
            
        } else if data[offset + 1] == 0x82 {
            // Length is encoded in 2 bytes (0x82 format)
            tlvLength = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            tlvValue = Array(data[(offset + 4)..<(offset + 4 + tlvLength)])
            nextTlv = tlvLength + 4
            
        } else {
            // Length is encoded directly in the next byte
            tlvLength = Int(data[offset + 1])
            tlvValue = Array(data[(offset + 2)..<(offset + 2 + tlvLength)])
            nextTlv = tlvLength + 2
        }
        
        return (tlvType, tlvValue, nextTlv)
    }
    
    
    func decodeBER_TLV(data: [UInt8]) -> [[UInt8]]? {
        var offset = 0
        var rtnList: [[UInt8]] = []
        
        while offset < data.count {
            
            guard offset < data.count else {
                os_log("Insufficient data for tag", log: apduLog, type: .debug)
                break
            }
            
            // Get TLV data
            guard let (tlvType, tlvValue, nextTlv) = getBER_TLV(data: data, offset: offset) else { return nil}
            
            // Update the pointer in the buffer
            offset += nextTlv
            
            // Append to the results list
            rtnList.append([tlvType] + tlvValue)
        }
        
        // If it's tag type 0x53, return the data only
        let tlv = getBER_TLV(data: data)
        guard let tlv0 = tlv?.0 else { return nil }
        if tlv0 == 0x53 {
            guard let data = tlv?.1 else { return nil }
            return decodeBER_TLV(data: data)
        } else {
            return rtnList
        }
    }
    
    func saveFacialImage(_ imageData: Data) {
        let directoryURL = URL(fileURLWithPath: "\(tempPath)image")
        
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            
            let fileURL = directoryURL.appendingPathComponent("facial_image.dat")
            try imageData.write(to: fileURL)
            os_log("Facial image data saved to %{public}s", log: apduLog, type: .default, fileURL.path)
            
        } catch {
            os_log("Failed to save image data: %{public}s", log: apduLog, type: .error, error.localizedDescription)
        }
    }
    
    func extractImageFromDat() {
        // Attempt to read the binary data from the .dat file
        os_log("Attempting to read facial image data from .dat file...", log: apduLog, type: .default)
        let datFile = "\(tempPath)image/facial_image.dat"
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: datFile))
            
            // Look for JP2 (JPEG 2000) or JPEG markers
            let jp2cMarker = Data("jp2c".utf8)
            let jpegStartMarker: [UInt8] = [0xFF, 0xD8]
            
            if let startIndex = data.range(of: jp2cMarker)?.lowerBound {
                // Handle JP2 extraction
                let jp2DataStart = data.index(startIndex, offsetBy: jp2cMarker.count)
                let jp2Data = data[jp2DataStart...]
                let outputJP2File = "\(tempPath)image/facial_image.jp2"
                try jp2Data.write(to: URL(fileURLWithPath: outputJP2File))
                os_log("JP2 image extracted and saved as %{public}s", log: apduLog, type: .default, outputJP2File)
                cardHolderInfo.imagePath = outputJP2File
                
            } else if let startIndex = data.range(of: Data(jpegStartMarker))?.lowerBound {
                // Handle JPEG extraction
                let jpegData = data[startIndex...]
                let outputJPEGFile = "\(tempPath)image/facial_image.jpg"
                try jpegData.write(to: URL(fileURLWithPath: outputJPEGFile))
                os_log("JPEG image extracted and saved as %{public}s", log: apduLog, type: .default, outputJPEGFile)
                cardHolderInfo.imagePath = outputJPEGFile
                
            } else {
                os_log("No valid JP2 or JPEG markers found in the file.", log: apduLog, type: .error)
            }
        } catch {
            os_log("Error occurred: %{public}s", log: apduLog, type: .error, error.localizedDescription)
        }
    }
    
    
    func hex_to_string(with hexData: Data) -> String{
        if let string = String(data: hexData, encoding: .utf8) {
            return string
        } else {
            return hexData.map { String(format: "%02X", $0) }.joined()
        }
    }
    
    
    func parseCCCResponse(_ response: [[UInt8]]) -> CardholderCapabilityContainer? {
        var version = ""
        var features = [String]()
        var biometricSupport = false
        var secureMessaging = false
        for field in response {
            guard let tag = field.first else { continue }
            
            switch tag {
            case 0xF0:  // Version Information
                // Assuming the version is in the second and third bytes
                version = "Version: \(field[1]).\(field[2])"
                
            case 0xF1:  // Feature 1
                features.append("Feature 1 supported: \(field[1])")
                
            case 0xF2:  // Feature 2
                features.append("Feature 2 supported: \(field[1])")
                
            case 0xF6:  // Biometric Support
                if field.count > 1 {
                    biometricSupport = field[1] == 1
                } else {
                    continue
                }
                
            case 0xF7:  // Secure Messaging
                if field.count > 1 {
                    secureMessaging = field[1] == 1
                } else {
                    continue
                }
                
            default:
                continue
            }
        }
        
        return CardholderCapabilityContainer(
            version: version,
            features: features,
            biometricSupport: biometricSupport,
            secureMessaging: secureMessaging
        )
    }
    
    private func writeLogs(log: String) {
        let newlinelog = log + "\n"
        if let fileHandle = try? FileHandle(forWritingTo: self.logPath!) {
            // Move to the end of the file to append
            fileHandle.seekToEndOfFile()
            
            // Convert your string to Data and write it to the file
            if let dataToAppend = newlinelog.data(using: .utf8) {
                fileHandle.write(dataToAppend)
            }
            
            // Close the file handle when done
            fileHandle.closeFile()
        } else {
            // If the file doesn't exist, create it and write the string to it
            do {
                try newlinelog.write(to: self.logPath!, atomically: true, encoding: .utf8)
            } catch {
                os_log("Failed to write log file: %{public}s", log: self.apduLog, type: .error, error.localizedDescription)
            }
            
        }
    }
    func retrieveData() {
        os_log("Retrieving facial image...", log: apduLog, type: .default)
        
        sendAPDUCommand(apdu: GET_FACIAL_IMAGE) { data, sw1, sw2 in
            if sw1 == 0x90 && sw2 == 0x00 {
                if self.debugMode {
                    self.writeLogs(log: "facial image: \(data)")
                }
                let tv_data = self.decodeBER_TLV(data: data)
                
                guard let tv_data else { return }
                for tv in tv_data {
                    
                    //                    if tv.count < 2 { return }
                    if tv.count < 2 { break }
                    let tlv_type = tv[0]
                    if tlv_type == 0xBC {
                        os_log("Facial Image Length: %{public}s", log: self.apduLog, type: .debug, String(tv.count))
                        self.saveFacialImage(Data(tv[1..<tv.count]))
                        self.extractImageFromDat()
                        
                        
                    }
                    
                }
                
            } else {
                os_log("Failed to retrieve facial image: SW1=%{public}s, SW2=%{public}s", log: self.apduLog, type: .error, String(format: "%02X", sw1), String(format: "%02X", sw2))
                
            }
            self.sendAPDUCommand(apdu: self.GET_CARDHOLDER_NAME) { data, sw1, sw2 in
                if sw1 == 0x90 && sw2 == 0x00 {
                    let tv_data = self.decodeBER_TLV(data: data)
                    
                    
                    guard let tv_data else { return }
                    if self.debugMode {
                        print(tv_data)
                    }
                    for tv in tv_data {
                        guard let tag = tv.first else { continue }
                        if self.debugMode {
                            self.writeLogs(log: "Card Holder Name: \(self.hex_to_string(with: Data(tv[1..<tv.count])))")
                            
                        }
                        switch tag {
                        case 1:
                            self.cardHolderInfo.name = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        case 2:
                            self.cardHolderInfo.employeeAffiliation = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        case 7:
                            self.cardHolderInfo.organization = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        case 4:
                            self.cardHolderInfo.expirationDate = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        case 5:
                            self.cardHolderInfo.cardSerialNumber = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        case 6:
                            self.cardHolderInfo.issueIdentifier = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        case 254:
                            break
                        default:
                            os_log("Unknown Tag %{public}s", log: self.apduLog, type: .debug, self.hex_to_string(with: Data(tv[1..<tv.count])))
                        }
                        
                        
                        
                        //                        if self.hex_to_string(with: Data(tv[1..<tv.count])) == "" {
                        //                            continue
                        //                        }
                        //                        self.cardHolderInfo.cardInfo.append(self.hex_to_string(with: Data(tv[1..<tv.count])))
                    }
                }
                
            }
            
            self.sendAPDUCommand(apdu: self.GET_CARD_CAPABILITY_CONTAINER) { data, sw1, sw2 in
                if sw1 == 0x90 && sw2 == 0x00 {
                    if self.debugMode {
                        self.writeLogs(log: "card capability container: \(data)")
                    }
                    let tv_data = self.decodeBER_TLV(data: data)
                    guard let tv_data else { return }
                    if let ccc = self.parseCCCResponse(tv_data) {
                        if self.debugMode {
                            self.writeLogs(log: "Parsed CCC Data: \(ccc)")
                        }
                        self.cardHolderInfo.CCCData = ccc
                        
                    } else {
                        os_log("Failed to parse CCC response", log: self.apduLog, type: .error)
                    }
                    
                }
                
            }
            self.sendAPDUCommand(apdu: self.GET_CARD_HOLDER_UNIQUE_IDENTIFIER) { data, sw1, sw2 in
                if sw1 == 0x90 && sw2 == 0x00 {
                    if self.debugMode {
                        self.writeLogs(log: "card holder unique identifier: \(data)")
                    }
                    let tv_data = self.decodeBER_TLV(data: data)
                    
                    //
                    guard let tv_data else { return }
                    for tv in tv_data {
                        let tlv_type = tv[0]
                        
                        if tlv_type == 0x30 {
                            let fascNData = Data(tv[1..<tv.count])
                            
                            self.extractFascNFields(from: fascNData)
                        }
                        //                        if tlv_type == 0x32 {
                        //                            print("Organization Identifier: \(self.hex_to_string(with: Data(tv[1..<tv.count])))")
                        //                        }
                        //                        if tlv_type == 0x33 {
                        //                            print("DUNS Number: \(self.hex_to_string(with: Data(tv[1..<tv.count])))")
                        //                        }
                        //                                    if tlv_type == 0x31 {
                        //                                        print("Agency Code: \(self.hex_to_string(with: Data(tv[1..<tv.count])))")
                        //                                    }
                        if tlv_type == 0x34 {
                            //                            print("GUID: \(self.hex_to_string(with: Data(tv[1..<tv.count])))")
                            self.cardHolderInfo.guid = self.hex_to_string(with: Data(tv[1..<tv.count]))
                        }
                        //                        if tlv_type == 0x36 {
                        //                            print("Cardholder UUID: \(self.hex_to_string(with: Data(tv[1..<tv.count])))")
                        //                        }
                        //                        if tlv_type == 0x35 {
                        //                            print("Expiration Date: \(self.getStr(inputList: tv))")
                        //                        }
                        //                        if tlv_type == 0x3E {
                        //                            print("Asymmetric Signature: \(tv.count - 1)")
                        //                        }
                        
                    }
                }
                
                self.smartCard?.endSession()
                self.delegate?.didReceiveUpdate(cardInfo: self.cardHolderInfo)
                
                
            }
            
        }
        
        
    }
    
    func decodeBCD(bcd_num: UInt8) -> String? {
        let bcd_table: [String: UInt8] = [
            "0": 0b00001,
            "1": 0b10000,
            "2": 0b01000,
            "3": 0b11001,
            "4": 0b00100,
            "5": 0b10101,
            "6": 0b01101,
            "7": 0b11100,
            "8": 0b00010,
            "9": 0b10011,
            "SS": 0b11010,
            "FS": 0b10110,
            "ES": 0b11111
        ]
        
        return bcd_table.first(where: { $0.value == bcd_num })?.key
    }
    
    func extractFascNFields(from data: Data) {
        var fasc_n_list: [String] = []
        var bitShiftedData = [UInt8]()
        
        // Combine bytes in chunks of 5 bits
        var bitBuffer: UInt64 = 0
        var bitCount = 0
        
        for byte in data {
            bitBuffer = (bitBuffer << 8) | UInt64(byte) // Shift buffer left 8 bits, add new byte
            bitCount += 8
            
            // While there are at least 5 bits available, extract them
            while bitCount >= 5 {
                let mask: UInt64 = 0b11111 << (bitCount - 5) // Mask the top 5 bits
                let bcd_num = (bitBuffer & mask) >> (bitCount - 5) // Extract 5 bits
                
                // Store the extracted 5-bit value
                bitShiftedData.append(UInt8(bcd_num))
                
                bitCount -= 5 // Reduce bit count by 5
            }
        }
        
        // Decode BCD values and collect the results
        for bcd in bitShiftedData {
            if let decoded = decodeBCD(bcd_num: bcd) {
                fasc_n_list.append(decoded)
            }
        }
        
        //        print("BCD Values: \(fasc_n_list)")
        convertFascNFields(from: fasc_n_list)
    }
    
    func convertFascNFields(from bcdValues: [String?]){
        os_log("Attempting to convert FASC-N fields...", log: apduLog, type: .default)
        let agencyCode = bcdValues[1...4].compactMap { $0 }.joined()
        let systemCode = bcdValues[6...9].compactMap { $0 }.joined()
        let credentialNumber = bcdValues[11...16].compactMap { $0 }.joined()
        let credentialSeries = bcdValues[18] ?? ""
        let individualCredentialIssue = bcdValues[20] ?? ""
        let personIdentifier = bcdValues[22...31].compactMap { $0 }.joined()
        let organizationalCategory = bcdValues[32] ?? ""
        let organizationalIdentifier = bcdValues[33...36].compactMap { $0 }.joined()
        let personAssociationCategory = bcdValues[37] ?? ""
        
        // Print extracted fields
        cardHolderInfo.ac = agencyCode
        cardHolderInfo.sc = systemCode
        
        cardHolderInfo.cn = credentialNumber
        cardHolderInfo.cs = credentialSeries
        
        cardHolderInfo.individualCredentail = individualCredentialIssue
        cardHolderInfo.personID = personIdentifier
        var orgCategory: String
        switch organizationalCategory
        {
        case "1":
            orgCategory = "Federal Government Agency"
        case "2":
            orgCategory = "State Government Agency"
        case "3":
            orgCategory = "Commercial Enterprise"
        case "4":
            orgCategory = "Foreign Government"
        default:
            orgCategory = "Unknown"
        }
        cardHolderInfo.orgCategory2 = orgCategory
        cardHolderInfo.orgID = organizationalIdentifier
        var personCategory: String
        switch personAssociationCategory
        {
        case "1":
            personCategory = "Employee"
        case "2":
            personCategory = "Civil"
        case "3":
            personCategory = "Executive Staff"
        case "4":
            personCategory = "Uniformed Service"
        case "5":
            personCategory = "Contractor"
        case "6":
            personCategory = "Organizational Affiliate"
        case "7":
            personCategory = "Organizational Beneficiary"
        default:
            personCategory = "Unknown"
        }
        cardHolderInfo.PersonCategory2 = personCategory
        
        if self.debugMode {
            
            
            let fascn = """
Agency Code: \(agencyCode)
System Code: \(systemCode)
Credential Number: \(credentialNumber)
Credential Series: \(credentialSeries)
Individual Credential Issue: \(individualCredentialIssue)
Person Identifier: \(personIdentifier)
Organizational Category: \(orgCategory) \(organizationalCategory)
Organizational Identifier: \(organizationalIdentifier)
Person Association Category: \(personCategory)
"""
            writeLogs(log: fascn)
            
        }
    }
    
    
    func getStr(inputList: [UInt8]) -> String {
        var output = ""
        for byte in inputList {
            // Convert the byte to a UnicodeScalar and then to a Character
            // This works because byte values are from 0 to 255, which can map to ASCII
            let scalar = UnicodeScalar(byte)
            output.append(Character(scalar))
            
        }
        return output
    }
    
    func initializeSmartCard(with pin: Data, with passedSlot: String) async {
        if debugMode {
            if let logPath = logPath {
                os_log("MY LOG: %{public}s", log: self.apduLog, type: .debug, logPath.absoluteString)
            }
        }
        let cardSlotManager = TKSmartCardSlotManager()
        os_log("Passed slot: %{public}s", log: self.apduLog, type: .debug, passedSlot)
        var slot: TKSmartCardSlot?
        for slotName in cardSlotManager.slotNames {
            if passedSlot == slotName {
                slotNameString = slotName
                slot = cardSlotManager.slotNamed(slotName)
            }
            
        }
        
        if let slot = slot {
            NSLog("Using reader: \(slot.name)")
            
            startSession(pin: pin, smartCardSlot: slot)
        }
        return
    }
    func sendVerifyPINCommand(pin: Data, smartCardSlot: TKSmartCardSlot, completion: @escaping (Bool) -> Void) {
        
        var pinArray: [UInt8] = [UInt8](pin)
        
        // Ensure the pin is of correct length (e.g., 8 bytes)
        if pinArray.count < 8 {
            // Pad with 0xFF if the PIN is too short
            pinArray += Array(repeating: 0xFF, count: 8 - pinArray.count)
        } else if pinArray.count > 8 {
            // Trim the PIN if it's too long
            pinArray = Array(pinArray.prefix(8))
        }
        
        // Construct the APDU for verifying the PIN (no padding after PIN)
        let verifyPINCommand: [UInt8] = [
            0x00, // CLA: Class byte
            0x20, // INS: Instruction byte (Verify)
            0x00, // P1: Parameter 1 (Verify type)
            0x80, // P2: Parameter 2 (PIN reference)
            0x08  // LC: Length of the PIN (8 bytes)
        ] + pinArray // Only the 8-byte PIN
        
        if self.debugMode {
            writeLogs(log: "APDU Command: \(verifyPINCommand)")
        }
        
        let verifyPinAPDUData = Data(verifyPINCommand)
        sendAPDUCommand(apdu: [UInt8](verifyPinAPDUData)) { data, sw1, sw2 in
            if sw1 == 0x90 && sw2 == 0x00 {
                os_log("PIN Verified Successfully", log: self.apduLog, type: .default)
                
                completion(true)
            } else {
                os_log("PIN verifiation failed", log: self.apduLog, type: .debug)
                
                completion(false)
            }
        }
    }
    
    func startSession(pin: Data, smartCardSlot: TKSmartCardSlot) {
        smartCard = smartCardSlot.makeSmartCard()
        
        smartCard?.beginSession( reply: { success , error in
            if !success {
                if let error = error {
                    os_log("Failed to start sessions: %{public}s", log: self.apduLog, type: .error, error.localizedDescription)
                }
                return
            }
            NSLog("Smartcard Session Started")
            self.sendAPDUCommand(apdu: self.SELECT_PIV_APPLICATION) { data, sw1, sw2 in
                if sw1 == 0x90 && sw2 == 0x00 {
                    os_log("PIV application selected successfully.", log: self.apduLog, type: .default)
                    self.sendVerifyPINCommand(pin: pin, smartCardSlot: smartCardSlot) { isVerified in
                        if isVerified {
                            self.retrieveData()
                            
                        } else {
                            var attemptsLeft = 0
                            let pinVerifyNull : [UInt8] = [ 0x00, 0x20, 0x00, 0x80, 0x00]
                            self.sendAPDUCommand(apdu: pinVerifyNull) { data, sw1, sw2 in
                                if sw1 == 0x63 && (sw2 & 0xC0) == 0xC0 {
                                    attemptsLeft = Int(sw2 & 0x0F)
                                    
                                    os_log("PIN Attempts Left: %{public}d", log: self.apduLog, type: .default, attemptsLeft)
                                    self.delegate?.pinFailed(slotName: self.slotNameString, attempts: attemptsLeft)
                                } else {
                                    os_log("Attempts Left: 0", log: self.apduLog, type: .default)
                                    self.delegate?.pinFailed(slotName: self.slotNameString, attempts: 0)
                                }
                            }
                            self.smartCard?.endSession()
                            
                            
                        }
                    }
                }
            }
        })
        
    }
    func sendAPDUCommand(apdu: [UInt8], completion: @escaping ([UInt8], UInt8, UInt8) -> Void) {
        
        // Convert command array to Data
        let apduData = Data(apdu)
        if debugMode {
            writeLogs(log: "Sending APDU: \(apdu.map { String(format: "%02X", $0) }.joined())")
        }
        
        if let smartCard = smartCard {
            smartCard.transmit(apduData) { response, error in
                guard let responseData = response, error == nil else {
                    os_log("Error transmitting APDU: %{public}s", log: self.apduLog, type: .error, error?.localizedDescription ?? "Unknown error")
                    completion([], 0x00, 0x00)
                    return
                }
                
                var responseBytes = Array(responseData.dropLast(2)) // Extract response without SW1, SW2
                let sw1 = responseData[responseData.count - 2]
                let sw2 = responseData[responseData.count - 1]
                if self.debugMode {
                    self.writeLogs(log: "APDU Response: \(responseBytes.map { String(format: "%02X", $0) }.joined()), SW1: \(String(format: "%02X", sw1)), SW2: \(String(format: "%02X", sw2))")
                }
                
                
                // Check if more data is available (SW1 == 0x61)
                if sw1 == 0x61 {
                    let getResponseCommand: [UInt8] = [
                        0x00, 0xC0, 0x00, 0x00, sw2
                    ]
                    
                    // Call sendAPDUCommand recursively to get the remaining data
                    self.sendAPDUCommand(apdu: getResponseCommand) { moreData, moreSW1, moreSW2 in
                        responseBytes += moreData // Combine the previously received data with the new data
                        
                        // Check the final SW1 and SW2
                        if moreSW1 == 0x90 && moreSW2 == 0x00 {
                            // Handle successful retrieval of all data
                            completion(responseBytes, moreSW1, moreSW2)
                        } else {
                            // Return the status words and received data
                            completion(responseBytes, moreSW1, moreSW2)
                        }
                    }
                } else {
                    // No more data, return the response and status words
                    completion(responseBytes, sw1, sw2)
                }
            }
        } else {
            completion([], 0, 0)
        }
    }
}
