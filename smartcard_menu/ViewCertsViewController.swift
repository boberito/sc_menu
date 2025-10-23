//
//  ViewCertsViewController.swift
//  SC Menu
//
//  Created by Bob Gendler on 10/16/25.
//

import Cocoa
import os
import SecurityInterface

class ViewCertsViewController: NSViewController {
    var selectedCert: SecIdentity? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        self.view.wantsLayer = true
        
        var secRef: SecCertificate? = nil
        
        guard let selectedCert else { return }
        let certRefErr = SecIdentityCopyCertificate(selectedCert, &secRef)
        if certRefErr != errSecSuccess {
            os_log("Error getting certificate from identity: %{public}@", log: OSLog.default, type: .error, String(describing: certRefErr))
            return
        }
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .lineBorder
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true

        let certView = SFCertificateView()
        guard let secRef = secRef else { return }
        
        certView.setCertificate(secRef)
        certView.setDetailsDisclosed(true)
        certView.setDisplayTrust(true)
        certView.setEditableTrust(true)
        certView.setDisplayDetails(true)
        certView.setPolicies(SecPolicyCreateBasicX509())
        certView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = certView
        view.addSubview(scrollView)

        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Provide certificate view a width and height constraint
            certView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            certView.heightAnchor.constraint(greaterThanOrEqualToConstant: 500) 
        ])
    }

}
    
