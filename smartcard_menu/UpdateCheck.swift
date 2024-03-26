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
    func check() -> Int{
        
        let sc_menuURL = "https://api.github.com/repos/boberito/sc_menu/releases/latest"
        var request = URLRequest(url: URL(string: sc_menuURL)!)
        request.timeoutInterval = 3.0
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        var version: String? = nil
        var updateNeeded = 0
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) {data,response,error in
            let httpResponse = response as? HTTPURLResponse
            let dataReturn = data
            if (error != nil) {
                NSLog("An Error Occured - offline or can't reach GitHub - \(String(describing: error))")
                updateNeeded = 2
                dispatchGroup.leave()
            } else {
                do {
                    switch httpResponse!.statusCode {
                    case 200:
                        let decoder = JSONDecoder()
                        if let githubData = try? decoder.decode(githubData.self, from: dataReturn!) {
                            version = githubData.tag_name
                            if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let gitHubVersion = version {
                                let versionCompare = currentVersion.compare(gitHubVersion, options: .numeric)
                                if versionCompare == .orderedSame {
                                    NSLog("SC Menu is update to date")
                                    updateNeeded = 0
                                } else if versionCompare == .orderedAscending {
                                    DispatchQueue.main.async {
                                        self.alert(githubVersion: gitHubVersion, current: currentVersion)
                                    }
                                    NSLog("Current is \(currentVersion), newest is \(gitHubVersion)")
                                    updateNeeded = 1
                                } else if versionCompare == .orderedDescending {
                                    NSLog("Current is \(currentVersion), version on GitHub is \(gitHubVersion)")
                                    updateNeeded = 0
                                }
                            }
                        }
                        dispatchGroup.leave()
                    default:
                        NSLog("Offline or cannot reach GitHub")
                        updateNeeded = 2
                        dispatchGroup.leave()
                    }
                }
            }
        }
        task.resume()
        dispatchGroup.wait()
        
        return updateNeeded
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
