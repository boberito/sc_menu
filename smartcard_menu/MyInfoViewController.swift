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
        
       
        if let pin = pin {
            Task {
                await apduFunctions.initializeSmartCard(with: pin)
            }
        } else {
            //close window
            return
        }
        
        let rect = NSRect(x: 0, y: 0, width: 700, height: 500)
        view = NSView(frame: rect)
        view.wantsLayer = true
        cardImageView.frame = NSRect(x: 10, y: 100, width: 242, height: 307)
        
        holderNameLabel.frame = NSRect(x: 360, y: 450, width: 200, height: 25)
        holderNameLabel.isBordered = true
        holderNameLabel.isBezeled = true
        holderNameLabel.isEditable = false
        holderNameLabel.drawsBackground = false
        holderNameLabel.isSelectable = true

        holderAffiliationLabel.frame = NSRect(x: 360, y: 425, width: 200, height: 25)
        holderAffiliationLabel.isBordered = true
        holderAffiliationLabel.isBezeled = true
        holderAffiliationLabel.isEditable = false
        holderAffiliationLabel.drawsBackground = false
        holderAffiliationLabel.isSelectable = true
        
        holderOrgLabel.frame = NSRect(x: 360, y: 400, width: 200, height: 25)
        holderOrgLabel.isBordered = true
        holderOrgLabel.isBezeled = true
        holderOrgLabel.isEditable = false
        holderOrgLabel.drawsBackground = false
        holderOrgLabel.isSelectable = true
        
        holderExpLabel.frame = NSRect(x: 360, y: 375, width: 200, height: 25)
        holderExpLabel.isBordered = true
        holderExpLabel.isBezeled = true
        holderExpLabel.isEditable = false
        holderExpLabel.drawsBackground = false
        holderExpLabel.isSelectable = true
        
        cardSerialLabel.frame = NSRect(x: 360, y:350, width: 200, height: 25)
        cardSerialLabel.isBordered = true
        cardSerialLabel.isBezeled = true
        cardSerialLabel.isEditable = false
        cardSerialLabel.drawsBackground = false
        cardSerialLabel.isSelectable = true
        
        issuerIdentifierLabel.frame = NSRect(x: 360, y:325, width: 200, height: 25)
        issuerIdentifierLabel.isBezeled = true
        issuerIdentifierLabel.isBordered = true
        issuerIdentifierLabel.isEditable = false
        issuerIdentifierLabel.drawsBackground = false
        issuerIdentifierLabel.isSelectable = true
        
        agencyCardSerialLabel.frame = NSRect(x: 360, y:300, width: 200, height: 25)
        agencyCardSerialLabel.isBezeled = true
        agencyCardSerialLabel.isBordered = true
        agencyCardSerialLabel.isEditable = false
        agencyCardSerialLabel.drawsBackground = false
        agencyCardSerialLabel.isSelectable = true
        
        systemCodeLabel.frame = NSRect(x: 360, y:275, width: 200, height: 25)
        systemCodeLabel.isBezeled = true
        systemCodeLabel.isBordered = true
        systemCodeLabel.isEditable = false
        systemCodeLabel.drawsBackground = false
        systemCodeLabel.isSelectable = true
        
        credentialsLabel.frame = NSRect(x: 360, y:250, width: 200, height:25)
        credentialsLabel.isBezeled = true
        credentialsLabel.isEditable = false
        credentialsLabel.isBordered = true
        credentialsLabel.isSelectable = true
        credentialsLabel.drawsBackground = true
        
        credentialSeriesLabel.frame = NSRect(x: 360, y:225, width: 200, height:25)
        credentialSeriesLabel.isBezeled = true
        credentialSeriesLabel.isEditable = false
        credentialSeriesLabel.isBordered = true
        credentialSeriesLabel.isSelectable = true
        credentialSeriesLabel.drawsBackground = true
        
        indivdualCredentialIssueLabel.frame = NSRect(x: 360, y:200, width: 200, height:25)
        indivdualCredentialIssueLabel.isBezeled = true
        indivdualCredentialIssueLabel.isEditable = false
        indivdualCredentialIssueLabel.isSelectable = true
        indivdualCredentialIssueLabel.drawsBackground = true
        indivdualCredentialIssueLabel.isBordered = true
        
        personIdentifierLabel.frame = NSRect(x: 360, y:175, width: 200, height:25)
        personIdentifierLabel.isBezeled = true
        personIdentifierLabel.isEditable = false
        personIdentifierLabel.isSelectable = true
        personIdentifierLabel.drawsBackground = true
        personIdentifierLabel.isBordered = true
        
        organizationalCategoryLabel.frame = NSRect(x: 360, y:150, width: 200, height: 25)
        organizationalCategoryLabel.isBezeled = true
        organizationalCategoryLabel.isEditable = false
        organizationalCategoryLabel.isSelectable = true
        organizationalCategoryLabel.drawsBackground = true
        organizationalCategoryLabel.isBordered = true
        
        organizationalCodeLabel.frame = NSRect(x: 360, y:125, width: 200, height:25)
        organizationalCategoryLabel.isBezeled = true
        organizationalCategoryLabel.isEditable = false
        organizationalCategoryLabel.isSelectable = true
        organizationalCategoryLabel.drawsBackground = true
        organizationalCategoryLabel.isBordered = true
        
        globalUniqueIdentifierLabel.frame = NSRect(x: 360, y:100, width: 200, height:25)
        globalUniqueIdentifierLabel.isBezeled = true
        globalUniqueIdentifierLabel.isEditable = false
        globalUniqueIdentifierLabel.isBordered = true
        globalUniqueIdentifierLabel.isSelectable = true
        globalUniqueIdentifierLabel.drawsBackground = true
        
        biometricsLabel.frame = NSRect(x:360, y:75, width: 200, height:25)
        biometricsLabel.isBezeled = true
        biometricsLabel.isBordered = true
        biometricsLabel.isEditable = false
        biometricsLabel.drawsBackground = true
        biometricsLabel.isSelectable = true
        
        secureMessagingLabel.frame = NSRect(x:360, y:50, width: 200, height:25)
        secureMessagingLabel.isBezeled = true
        secureMessagingLabel.isBordered = true
        secureMessagingLabel.drawsBackground = true
        secureMessagingLabel.isSelectable = true
        secureMessagingLabel.isEditable = false
        
        view.addSubview(cardImageView)
        view.addSubview(holderNameLabel)
        view.addSubview(holderAffiliationLabel)
        view.addSubview(holderOrgLabel)
        view.addSubview(holderExpLabel)
        view.addSubview(cardSerialLabel)
        view.addSubview(issuerIdentifierLabel)
        view.addSubview(agencyCardSerialLabel)
        view.addSubview(systemCodeLabel)
        view.addSubview(credentialsLabel)
        view.addSubview(credentialSeriesLabel)
        view.addSubview(indivdualCredentialIssueLabel)
        view.addSubview(personIdentifierLabel)
        view.addSubview(organizationalCategoryLabel)
        view.addSubview(organizationalCodeLabel)
        view.addSubview(globalUniqueIdentifierLabel)
        view.addSubview(biometricsLabel)
        view.addSubview(secureMessagingLabel)
        
        
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
