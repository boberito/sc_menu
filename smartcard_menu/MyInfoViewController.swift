//
//  MyInfoViewController.swift
//  SC Menu
//
//  Created by Bob Gendler on 11/1/24.
//
import Cocoa
import os

class MyInfoViewController: NSViewController, APDUDelgate {
    
    let apduFunctions = smartCardAPDU()
    
    var passedSlot: String? = nil
    var pin: Data? = nil
    func didReceiveUpdate(cardInfo: CardHolderInfo) {
//      do things
        print("Hello from the update")
        if FileManager.default.fileExists(atPath: cardInfo.imagePath!) {
            DispatchQueue.main.async {
                self.cardImageView.image = NSImage(contentsOfFile: cardInfo.imagePath!)
            }
            
        } else {
            os_log("Image file not found at path: %@", log: prefsLog, type: .error, cardInfo.imagePath!)
        }
        DispatchQueue.main.async {
            if let name = cardInfo.cardInfo[1], let affilation = cardInfo.cardInfo[2], let orgAffilation = cardInfo.cardInfo[3], let exp = cardInfo.cardInfo[4], let cardSerial = cardInfo.cardInfo[5], let issuerIdent = cardInfo.cardInfo[6] {
                self.holderNameLabel.stringValue = name
                self.holderAffiliationLabel.stringValue = affilation
                self.holderOrgLabel.stringValue = orgAffilation
                
        
                let startIndex = exp.startIndex
                let yearRange = startIndex..<exp.index(startIndex, offsetBy: 4)  // "2028"
                let monthRange = exp.index(startIndex, offsetBy: 4)..<exp.index(startIndex, offsetBy: 7)  // "JUN"
                let dayRange = exp.index(startIndex, offsetBy: 7)..<exp.index(startIndex, offsetBy: 9)  // "09"

                // Extract components
                let year = String(exp[yearRange])
                let month = String(exp[monthRange])
                let day = String(exp[dayRange])

                // Combine into formatted string
                let formattedDate = "\(month)-\(day)-\(year)"

                // Assign to holderExpLabel
                self.holderExpLabel.stringValue = formattedDate

                self.cardSerialLabel.stringValue = cardSerial
                
                self.issuerIdentifierLabel.stringValue = issuerIdent
                
                
            }
            if let ac = cardInfo.ac {
                self.agencyCardSerialLabel.stringValue = ac
            }
            
            if let sc = cardInfo.sc {
                self.systemCodeLabel.stringValue = sc
            }
            
            if let cn = cardInfo.cn {
                self.credentialsLabel.stringValue = cn
            }
            
            if let cs = cardInfo.cs {
                self.credentialSeriesLabel.stringValue = cs
            }
            if let ic = cardInfo.individualCredentail {
                self.indivdualCredentialIssueLabel.stringValue = ic
                
            }
            if let pi = cardInfo.personID {
                self.personIdentifierLabel.stringValue = pi
            }
            
            if let orgCategory = cardInfo.orgCategory2 {
                self.organizationalCategoryLabel.stringValue = orgCategory
            }
            
            if let orgID = cardInfo.orgID {
                self.organizationalCodeLabel.stringValue = orgID
            }
            
            if let guid = cardInfo.guid {
                self.globalUniqueIdentifierLabel.stringValue = guid
            }
            
            if let cccData = cardInfo.CCCData {
                self.secureMessagingLabel.stringValue = String(cccData.secureMessaging)
                self.biometricsLabel.stringValue = String(cccData.biometricSupport)
            }
            
            
        }
   
    }

    let cardImageView = NSImageView()
    
    let holderNameLabel = NSTextField()
    let holderAffiliationLabel = NSTextField()
    let holderOrgLabel = NSTextField()
    let holderExpLabel = NSTextField()
    let cardSerialLabel = NSTextField()
    let issuerIdentifierLabel = NSTextField()

    
    let agencyCardSerialLabel = NSTextField()
    let organizationalCodeLabel = NSTextField()
    let agencyCodeLabel = NSTextField()
    let systemCodeLabel = NSTextField()
    let credentialsLabel = NSTextField()
    let credentialSeriesLabel = NSTextField()
    let indivdualCredentialIssueLabel = NSTextField()
    let personIdentifierLabel = NSTextField()
    let organizationalCategoryLabel = NSTextField()
    let personAssociationCategoryLabel = NSTextField()
    let globalUniqueIdentifierLabel = NSTextField()



    let biometricsLabel = NSTextField()
    let secureMessagingLabel = NSTextField()
    
    private let prefsLog = OSLog(subsystem: subsystem, category: "My Card Info")
    override func loadView() {
        
        
        apduFunctions.delegate = self
        
       
        if let pin = pin, let passedSlot = passedSlot {
            Task {
                await apduFunctions.initializeSmartCard(with: pin, with: passedSlot)
            }
        } else {
            //close window
            return
        }
        
        let rect = NSRect(x: 0, y: 0, width: 700, height: 500)
        view = NSView(frame: rect)
        view.wantsLayer = true
        cardImageView.frame = NSRect(x: 35, y: 100, width: 242, height: 307)
        
        let holderName = NSTextField()
        holderName.frame = NSRect(x:290, y:445, width: 100, height:25)
        holderName.stringValue = "Name:"
        holderName.isBordered = false
        holderName.isBezeled = false
        holderName.isEditable = false
        holderName.drawsBackground = false
        holderName.isSelectable = false
        
        
        holderNameLabel.frame = NSRect(x: 465, y: 450, width: 200, height: 25)
        holderNameLabel.isBezeled = true
        holderNameLabel.isBordered = true
        holderNameLabel.isEditable = false
        holderNameLabel.drawsBackground = true
        holderNameLabel.isSelectable = true
        
        let holderAffiliation = NSTextField()
        holderAffiliation.frame = NSRect(x:290, y:420, width: 200, height: 25)
        holderAffiliation.isEditable = false
        holderAffiliation.drawsBackground = false
        holderAffiliation.isSelectable = false
        holderAffiliation.isBezeled = false
        holderAffiliation.isBordered = false
        holderAffiliation.stringValue = "Employee Affiliation:"
        
        holderAffiliationLabel.frame = NSRect(x: 465, y: 425, width: 200, height: 25)
        holderAffiliationLabel.isBezeled = true
        holderAffiliationLabel.isBordered = true
        holderAffiliationLabel.isEditable = false
        holderAffiliationLabel.drawsBackground = true
        holderAffiliationLabel.isSelectable = true
        
        let holderOrg = NSTextField()
        holderOrg.frame = NSRect(x:290, y:395, width: 200, height: 25)
        holderOrg.isEditable = false
        holderOrg.drawsBackground = false
        holderOrg.isSelectable = false
        holderOrg.isBezeled = false
        holderOrg.isBordered = false
        holderOrg.stringValue = "Organization Affiliation:"
        
        holderOrgLabel.frame = NSRect(x: 465, y: 400, width: 200, height: 25)
        holderOrgLabel.isBezeled = true
        holderOrgLabel.isBordered = true
        holderOrgLabel.isEditable = false
        holderOrgLabel.drawsBackground = true
        holderOrgLabel.isSelectable = true
        
        
        let expDate = NSTextField()
        expDate.frame = NSRect(x:290, y:370, width: 200, height: 25)
        expDate.isEditable = false
        expDate.drawsBackground = false
        expDate.isSelectable = false
        expDate.isBezeled = false
        expDate.isBordered = false
        expDate.stringValue = "Expiration Date:"
        
        holderExpLabel.frame = NSRect(x: 465, y: 375, width: 200, height: 25)
        holderExpLabel.isBezeled = true
        holderExpLabel.isBordered = true
        holderExpLabel.isEditable = false
        holderExpLabel.drawsBackground = true
        holderExpLabel.isSelectable = true
        
        let cardSerial = NSTextField()
        cardSerial.frame = NSRect(x:290, y:345, width: 200, height: 25)
        cardSerial.isEditable = false
        cardSerial.drawsBackground = false
        cardSerial.isSelectable = false
        cardSerial.isBezeled = false
        cardSerial.isBordered = false
        cardSerial.stringValue = "Card Serial Number:"
        
        cardSerialLabel.frame = NSRect(x: 465, y:350, width: 200, height: 25)
        cardSerialLabel.isBezeled = true
        cardSerialLabel.isBordered = true
        cardSerialLabel.isEditable = false
        cardSerialLabel.drawsBackground = true
        cardSerialLabel.isSelectable = true
        
        let issuerIdentifier = NSTextField()
        issuerIdentifier.frame = NSRect(x:290, y:320, width: 200, height: 25)
        issuerIdentifier.isEditable = false
        issuerIdentifier.drawsBackground = false
        issuerIdentifier.isSelectable = false
        issuerIdentifier.isBezeled = false
        issuerIdentifier.stringValue = "Issuer Identifier:"
        issuerIdentifier.isBezeled = false
        
        issuerIdentifierLabel.frame = NSRect(x: 465, y:325, width: 200, height: 25)
        issuerIdentifierLabel.isBezeled = true
        issuerIdentifierLabel.isBordered = true
        issuerIdentifierLabel.isEditable = false
        issuerIdentifierLabel.drawsBackground = true
        issuerIdentifierLabel.isSelectable = true
        
        let agencyCardSerial = NSTextField()
        agencyCardSerial.frame = NSRect(x:290, y:295, width: 200, height: 25)
        agencyCardSerial.isEditable = false
        agencyCardSerial.drawsBackground = false
        agencyCardSerial.isSelectable = false
        agencyCardSerial.isBezeled = false
        agencyCardSerial.stringValue = "Agency Card Serial:"
        
        agencyCardSerialLabel.frame = NSRect(x: 465, y:300, width: 200, height: 25)
        agencyCardSerialLabel.isBezeled = true
        agencyCardSerialLabel.isBordered = true
        agencyCardSerialLabel.isEditable = false
        agencyCardSerialLabel.drawsBackground = true
        agencyCardSerialLabel.isSelectable = true
        
        let systemCode = NSTextField()
        systemCode.frame = NSRect(x:290, y:270, width: 200, height: 25)
        systemCode.isEditable = false
        systemCode.drawsBackground = false
        systemCode.isSelectable = false
        systemCode.isBezeled = false
        systemCode.stringValue = "System Code:"
        
        systemCodeLabel.frame = NSRect(x: 465, y:275, width: 200, height: 25)
        systemCodeLabel.isBezeled = true
        systemCodeLabel.isBordered = true
        systemCodeLabel.isEditable = false
        systemCodeLabel.drawsBackground = true
        systemCodeLabel.isSelectable = true
        
        let credentialsNumber = NSTextField()
        credentialsNumber.frame = NSRect(x: 290, y:245, width: 200, height: 25)
        credentialsNumber.isEditable = false
        credentialsNumber.drawsBackground = false
        credentialsNumber.isSelectable = false
        credentialsNumber.isBezeled = false
        credentialsNumber.stringValue = "Credential Number:"
        
        credentialsLabel.frame = NSRect(x: 465, y:250, width: 200, height:25)
        credentialsLabel.isBezeled = true
        credentialsLabel.isEditable = false
        credentialsLabel.isBordered = true
        credentialsLabel.isSelectable = true
        credentialsLabel.drawsBackground = true
        
        let credentialSeries = NSTextField()
        credentialSeries.frame = NSRect(x: 290, y:220, width: 200, height: 25)
        credentialSeries.isEditable = false
        credentialSeries.drawsBackground = false
        credentialSeries.isSelectable = false
        credentialSeries.isBezeled = false
        credentialSeries.stringValue = "Credential Series:"
        
        credentialSeriesLabel.frame = NSRect(x: 465, y:225, width: 200, height:25)
        credentialSeriesLabel.isBezeled = true
        credentialSeriesLabel.isEditable = false
        credentialSeriesLabel.isBordered = true
        credentialSeriesLabel.isSelectable = true
        credentialSeriesLabel.drawsBackground = true
        
        let individualCredentialIssue = NSTextField()
        individualCredentialIssue.frame = NSRect(x: 290, y:195, width: 200, height: 25)
        individualCredentialIssue.isEditable = false
        individualCredentialIssue.drawsBackground = false
        individualCredentialIssue.isSelectable = false
        individualCredentialIssue.isBezeled = false
        individualCredentialIssue.stringValue = "Individual Credential Issue:"
        
        indivdualCredentialIssueLabel.frame = NSRect(x: 465, y:200, width: 200, height:25)
        indivdualCredentialIssueLabel.isBezeled = true
        indivdualCredentialIssueLabel.isEditable = false
        indivdualCredentialIssueLabel.isSelectable = true
        indivdualCredentialIssueLabel.drawsBackground = true
        indivdualCredentialIssueLabel.isBordered = true
        
        let personIdentifier = NSTextField()
        personIdentifier.frame = NSRect(x: 290, y: 170, width: 200, height: 25)
        personIdentifier.isEditable = false
        personIdentifier.isBezeled = false
        personIdentifier.isBordered = false
        personIdentifier.drawsBackground = false
        personIdentifier.isSelectable = false
        personIdentifier.stringValue = "Person Identifier:"
        
        personIdentifierLabel.frame = NSRect(x: 465, y:175, width: 200, height:25)
        personIdentifierLabel.isBezeled = true
        personIdentifierLabel.isEditable = false
        personIdentifierLabel.isSelectable = true
        personIdentifierLabel.drawsBackground = true
        personIdentifierLabel.isBordered = true
        
        let orgCat = NSTextField()
        orgCat.frame = NSRect(x: 290, y: 145, width: 200, height: 25)
        orgCat.isEditable = false
        orgCat.isBezeled = false
        orgCat.isBordered = false
        orgCat.drawsBackground = false
        orgCat.isSelectable = false
        orgCat.stringValue = "Organizational Category:"
        
        organizationalCategoryLabel.frame = NSRect(x: 465, y:150, width: 200, height: 25)
        organizationalCategoryLabel.isBezeled = true
        organizationalCategoryLabel.isEditable = false
        organizationalCategoryLabel.isSelectable = true
        organizationalCategoryLabel.drawsBackground = true
        organizationalCategoryLabel.isBordered = true
        
        let orgID = NSTextField()
        orgID.frame = NSRect(x: 290, y: 120, width: 200, height: 25)
        orgID.isEditable = false
        orgID.isBezeled = false
        orgID.isBordered = false
        orgID.isSelectable = false
        orgID.drawsBackground = false
        orgID.stringValue = "Organizational Identifier:"
        
        organizationalCodeLabel.frame = NSRect(x: 465, y:125, width: 200, height:25)
        organizationalCodeLabel.isBezeled = true
        organizationalCodeLabel.isBordered = true
        organizationalCodeLabel.isEditable = false
        organizationalCodeLabel.drawsBackground = true
        organizationalCodeLabel.isSelectable = true

        let globalUniqueIdentifier = NSTextField()
        globalUniqueIdentifier.frame = NSRect(x: 290, y: 95, width: 200, height: 25)
        globalUniqueIdentifier.isBezeled = false
        globalUniqueIdentifier.isBordered = false
        globalUniqueIdentifier.isSelectable = false
        globalUniqueIdentifier.isEditable = false
        globalUniqueIdentifier.drawsBackground = false
        globalUniqueIdentifier.stringValue = "Global Unique Identifier:"
        
        globalUniqueIdentifierLabel.frame = NSRect(x: 465, y:100, width: 200, height:25)
        globalUniqueIdentifierLabel.isBezeled = true
        globalUniqueIdentifierLabel.isEditable = false
        globalUniqueIdentifierLabel.isBordered = true
        globalUniqueIdentifierLabel.isSelectable = true
        globalUniqueIdentifierLabel.drawsBackground = true
        
        let biometricSupportLabel = NSTextField()
        biometricSupportLabel.frame = NSRect(x: 290, y: 70, width: 200, height: 25)
        biometricSupportLabel.isBezeled = false
        biometricSupportLabel.isBordered = false
        biometricSupportLabel.isSelectable = false
        biometricSupportLabel.isEditable = false
        biometricSupportLabel.drawsBackground = false
        biometricSupportLabel.stringValue = "Biometric Support:"
        
        biometricsLabel.frame = NSRect(x: 465, y:75, width: 200, height:25)
        biometricsLabel.isBezeled = true
        biometricsLabel.isBordered = true
        biometricsLabel.isEditable = false
        biometricsLabel.drawsBackground = true
        biometricsLabel.isSelectable = true
        
        let secureMessagingSupportLabel = NSTextField()
        secureMessagingSupportLabel.frame = NSRect(x: 290, y: 45, width: 200, height: 25)
        secureMessagingSupportLabel.isEditable = false
        secureMessagingSupportLabel.isBordered = false
        secureMessagingSupportLabel.isBezeled = false
        secureMessagingSupportLabel.isSelectable = true
        secureMessagingSupportLabel.drawsBackground = false
        secureMessagingSupportLabel.stringValue = "Secure Messaging Support:"
        
        secureMessagingLabel.frame = NSRect(x: 465, y:50, width: 200, height:25)
        secureMessagingLabel.isBezeled = true
        secureMessagingLabel.isBordered = true
        secureMessagingLabel.drawsBackground = true
        secureMessagingLabel.isSelectable = true
        secureMessagingLabel.isEditable = false
        
        view.addSubview(cardImageView)
        view.addSubview(holderNameLabel)
        view.addSubview(holderName)
        view.addSubview(holderAffiliationLabel)
        view.addSubview(holderAffiliation)
        view.addSubview(holderOrgLabel)
        view.addSubview(holderOrg)
        view.addSubview(holderExpLabel)
        view.addSubview(expDate)
        view.addSubview(cardSerialLabel)
        view.addSubview(cardSerial)
        view.addSubview(issuerIdentifierLabel)
        view.addSubview(issuerIdentifier)
        view.addSubview(agencyCardSerialLabel)
        view.addSubview(agencyCardSerial)
        view.addSubview(systemCodeLabel)
        view.addSubview(systemCode)
        view.addSubview(credentialsLabel)
        view.addSubview(credentialsNumber)
        view.addSubview(credentialSeriesLabel)
        view.addSubview(credentialSeries)
        view.addSubview(indivdualCredentialIssueLabel)
        view.addSubview(individualCredentialIssue)
        view.addSubview(personIdentifierLabel)
        view.addSubview(personIdentifier)
        view.addSubview(organizationalCategoryLabel)
        view.addSubview(orgCat)
        view.addSubview(organizationalCodeLabel)
        view.addSubview(orgID)
        view.addSubview(globalUniqueIdentifierLabel)
        view.addSubview(globalUniqueIdentifier)
        view.addSubview(biometricsLabel)
        view.addSubview(biometricSupportLabel)
        view.addSubview(secureMessagingLabel)
        view.addSubview(secureMessagingSupportLabel)
        
    }
    
    override func viewWillAppear() {
       
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
