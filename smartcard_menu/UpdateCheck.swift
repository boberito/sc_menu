//
//  UpdateCheck.swift
//  SC Menu
//
//  Created by Bob Gendler on 3/25/24.
//
import Cocoa
import os

/// Minimal subset of the GitHub Releases JSON payload we care about.
/// `tag_name` is compared numerically to the app's `CFBundleShortVersionString`.
struct githubData: Decodable {
    let tag_name: String
}

/// Performs a lightweight update check against GitHub Releases and optionally presents
/// a prompt to download the latest version.
///
/// Returns:
/// - 0: Up-to-date or newer than GitHub
/// - 1: Update available
/// - 2: Network/offline error
class UpdateCheck {
    private let updateLog = OSLog(subsystem: subsystem, category: "Updater")
    
    /// Fetch latest release version from GitHub and compare with the current app version.
    /// Uses a short timeout to avoid blocking app startup.
    func check() async -> Int{
        
        let sc_menuURL = "https://api.github.com/repos/boberito/sc_menu/releases/latest"
        var request = URLRequest(url: URL(string: sc_menuURL)!)
        request.timeoutInterval = 3.0
        
        request.timeoutInterval = 3.0
        var updateNeeded = 0
        var version: String? = nil
        if let (data, response) = try? await URLSession.shared.data(for: request) {
            let httpResponseCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if httpResponseCode == 200 {
                let decoder = JSONDecoder()
                if let githubData = try? decoder.decode(githubData.self, from: data) {
                        version = githubData.tag_name
                        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let gitHubVersion = version {
                            let versionCompare = currentVersion.compare(gitHubVersion, options: .numeric)
                            if versionCompare == .orderedSame {
                                os_log("SC Menu is up to date", log: self.updateLog, type: .default)
                                updateNeeded = 0
                            } else if versionCompare == .orderedAscending {
                                
                                alert(githubVersion: gitHubVersion, current: currentVersion)
                                
                                os_log("Current is %{public}s, newest is %{public}s", log: self.updateLog, type: .default, currentVersion.description, gitHubVersion.description)
                                updateNeeded = 1
                            } else if versionCompare == .orderedDescending {
                                os_log("Current is %{public}s, version on GitHub is %{public}s", log: self.updateLog, type: .default, currentVersion.description, gitHubVersion.description)
                                updateNeeded = 0
                            }
                        }
                    }
            }
            
        } else {
            os_log("An Error Occured - offline or can't reach GitHub", log: self.updateLog, type: .error)
            updateNeeded = 2
        }
        
        return updateNeeded

    }
    
    /// Present a modal alert offering to open the Releases page when a newer version is detected.
    func alert(githubVersion: String, current: String) {
        DispatchQueue.main.async { [ weak self ] in
            guard let self else { return }
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
                os_log("Update later", log: self.updateLog, type: .default)
            default:
                os_log("Somehow closed the alert without pushing a button", log: self.updateLog, type: .error)
            }
        }
    }
    
}
