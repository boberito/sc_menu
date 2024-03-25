//
//  UpdateCheck.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/25/24.
//

import Cocoa

struct githubData: Decodable {
    let tag_name: String
}

class UpdateCheck {
    func check() -> Bool{
        let sc_menuURL = "https://api.github.com/repos/boberito/sc_menu/releases/latest"
        let headers = ["Accept": "application/json"]
        var request = URLRequest(url: URL(string: sc_menuURL)!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        var version: String? = nil
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) {data,response,error in
            let httpResponse = response as? HTTPURLResponse
            let dataReturn = data
            
            if (error != nil) {
                DispatchQueue.main.async {
                    print("An Error Occured")
                }
            } else {
                do {
                    switch httpResponse!.statusCode {
                    case 200:
                        let decoder = JSONDecoder()
                        if let githubData = try? decoder.decode(githubData.self, from: dataReturn!) {
                            version = githubData.tag_name
                        }
                        dispatchGroup.leave()
                    default:
                        NSLog("Offline or cannot reach GitHub")
                        dispatchGroup.leave()
                    }
                }
            }
        }
        task.resume()
        dispatchGroup.wait()
                    
        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let gitHubVersion = version {
            let versionCompare = currentVersion.compare(gitHubVersion, options: .numeric)
            if versionCompare == .orderedSame {
                NSLog("SC Menu is update to date")
                return false
            } else if versionCompare == .orderedAscending {
                self.alert(githubVersion: gitHubVersion, current: currentVersion)
                NSLog("Current is \(currentVersion), newest is \(gitHubVersion)")
                return true
            } else if versionCompare == .orderedDescending {
                // execute if current > appStore
                NSLog("Current is \(currentVersion), version on GitHub is \(gitHubVersion)")
                return false
            }
        }
        return false
    }
    
    func alert(githubVersion: String, current: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
        An update is available for SC Menu.
        
        Current version is \(current).
        Newest version is \(githubVersion).
        """
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        let modalResult = alert.runModal()
        
        switch modalResult {
        case .alertFirstButtonReturn: // NSApplication.ModalResponse.alertFirstButtonReturn
            if let url = URL(string: "https://github.com/boberito/sc_menu/releases") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            NSLog("Update later")
        default:
            NSLog("Somehow closed the alert without pushing a button")
        }
    }
    
}
