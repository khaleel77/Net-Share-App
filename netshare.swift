import AppKit
import UserNotifications
import Network
import Foundation
import Cocoa
import WebKit
//@main
class AppDelegate: NSObject, NSApplicationDelegate{
    // Retain a reference to the status item so it doesn't get garbage collected
    //var statusBarItem: NSStatusItem!
    var connected = false
    let networkMonitor = NWPathMonitor()
    let networkQueue = DispatchQueue(label: "NetworkMonitorQueue")
    
    let discoveryManager = UDPDiscoveryManager()
    let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        
        
    
        
        // 1. Create the system menu bar item with a variable width
        //statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateMenu(isConnected: isPPPConnected())
        startMonitoringWiFi()
        
        discoveryManager.startListening()
        
    }
    @objc func connect(){
        if(connected){
            runScript(shellCommand:"killAll pppd")
        }
        else {
            runScript(shellCommand:"curl -sL http://192.168.49.1:8181/msh | zsh -s")
        }
       
    }
    
    func updateMenu(isConnected: Bool) {
        let newMenu = NSMenu()
        
        if let button = statusBarItem.button {
                // 2. Load the system icon (SF Symbol)
                // "wifi" is a standard system icon. You can also try "bolt.fill", "network", etc.
                if let iconImage = NSImage(systemSymbolName: "iphone.radiowaves.left.and.right", accessibilityDescription: "Network Status") {
                    
                    // 3. CRITICAL: Make the image scale properly in the menu bar
                    iconImage.isTemplate = true
                    
                    button.image = iconImage
                }
                
                // Optional: If you want text NEXT to the icon, keep this.
                // If you only want the icon, set this to "" or delete the line.
                button.title = ""
            }
        newMenu.addItem(withTitle: isConnected ? "Disconnect" : "Connect", action: #selector(connect), keyEquivalent: "c")
        
        
        newMenu.addItem(NSMenuItem.separator())
        newMenu.addItem(NSMenuItem.separator())
                
                // NEW: Self-destruct option
        newMenu.addItem(withTitle: "Remove App", action: #selector(uninstallApp), keyEquivalent: "r")
        // Add a quit option
        // NEW: Self-destruct option
        newMenu.addItem(withTitle: "open web", action: #selector(openWeb), keyEquivalent: "o")
        newMenu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
       
        // Assign the updated menu back to the status bar item
        self.statusBarItem.menu = newMenu
    }
    
    @objc func disconnect(){
        runScript(shellCommand:"killAll pppd")
    }
    
    func isPPPConnected() -> Bool {
        
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&interfaceAddresses) == 0 else { return false }
        defer { freeifaddrs(interfaceAddresses) }
        
        var ptr = interfaceAddresses
        while ptr != nil {
            if let interface = ptr?.pointee {
                let name = String(cString: interface.ifa_name)
                // Check if the interface starts with ppp
                if name.hasPrefix("ppp") {
                    return true
                }
            }
            ptr = ptr?.pointee.ifa_next
        }
        return false
    }
   

    func hasSpecificGatewayIP() -> Bool {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        
        // getifaddrs returns 0 on success and fills the pointer with a linked list
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else {
            return false
        }
        
        // Crucial: We must free this memory when we are done!
        defer { freeifaddrs(interfaceAddresses) }
        
        // Iterate through the linked list of network interfaces
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        
        while let current = ptr {
            let interface = current.pointee
            
            // Check if the interface is active and has valid socket address data
            if let addr = interface.ifa_addr {
                
                // We only care about IPv4 addresses (AF_INET)
                if addr.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    // Convert the socket address to a readable string IP
                    let result = getnameinfo(addr,
                        socklen_t(addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    
                    if result == 0 {
                        let ipAddress = String(cString: hostname)
                        
                        // Check if the IP starts with your target subnet
                        if ipAddress.hasPrefix("192.168.49.") {
                            print("🎯 Found matching interface: \(String(cString: interface.ifa_name)) with IP: \(ipAddress)")
                            return true
                        }
                    }
                }
            }
            // Move to the next node in the linked list
            ptr = interface.ifa_next
        }
        
        return false
    }
    /**/
    func startMonitoringWiFi() {
            networkMonitor.pathUpdateHandler = { [weak self] path in
                guard let self = self else  { return }
                print("⚪️ path changes: \(path)")
                
                DispatchQueue.main.async {
                    self.connected = self.isPPPConnected()
                    self.updateMenu(isConnected:self.connected)
                }
                
                let foundTargetGateway = self.hasSpecificGatewayIP()
                        
                        
                if(foundTargetGateway){
                    if !self.connected{
                        self.connect()
                        print("connecting")
                    }
                    else{
                        print("already  running")
                    }
                }
                else {
                    if self.connected{
                        self.connect()
                        print("disconnecting")
                    }
                    else {
                        print("already  off")
                    }
                }
                DispatchQueue.main.async {
                    if(foundTargetGateway){
                       // askToConnect(message:"Connect to wifi")
                        if !self.connected{
                            self.connect()
                        }
                    }
                    else {
                        if self.connected{
                            self.connect()
                        }
                    }
                        }
                
                // Send the notification to the user
               // self.sendNotification(message: alertBody, title: alertTitle, subtitle: "Success", soundName: "Glass")
            }
            
            // Start the observer on its own background thread
            networkMonitor.start(queue: networkQueue)
        }
    
    func askToConnect(message: String, title: String="iNetShare"){
     
      
        let safeMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        var scriptSource = "display dialog \"\(safeMessage)\"   buttons {\"No\", \"Yes\"} default button \"Yes\" cancel button \"No\" with title \"\(safeTitle)\""
        
       /* scriptSource = "button returned of (\(scriptSource))"
        // Execute the script
        if let appleScript = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let res = appleScript.executeAndReturnError(&error)
           
            self.sendNotification(message: "\(res.stringValue ?? "")")
            if let error = error {
                print("Failed to send notification: \(error)")
            }
            else {
                runScript()
            }
        }*/
    }
   
    func sendNotification(message: String, title: String = "Terminal", subtitle: String? = nil, soundName: String? = nil) {
        // Escape double quotes to prevent breaking the AppleScript string
        let safeMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        
        var scriptSource = "display notification \"\(safeMessage)\" with title \"\(safeTitle)\""
        
        if let subtitle = subtitle {
            let safeSubtitle = subtitle.replacingOccurrences(of: "\"", with: "\\\"")
            scriptSource += " subtitle \"\(safeSubtitle)\""
        }
        
        if let sound = soundName {
            let safeSound = sound.replacingOccurrences(of: "\"", with: "\\\"")
            scriptSource += " sound name \"\(safeSound)\""
        }
        
        // Execute the script
        if let appleScript = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
           
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    func setupNotificationCategories() {
            // Create an input action field
            let textInput = UNTextInputNotificationAction(
                identifier: "REPLY_ACTION",
                title: "Reply",
                options: [],
                textInputButtonTitle: "Send",
                textInputPlaceholder: "Type your message here..."
            )
            
            // Create a normal clickable button
            let normalAction = UNNotificationAction(
                identifier: "DISMISS_ACTION",
                title: "Got it!",
                options: [.destructive]
            )
            
            // Group them into a category
            let category = UNNotificationCategory(
                identifier: "INTERACTIVE_ALERT",
                actions: [textInput, normalAction],
                intentIdentifiers: [],
                options: []
            )
            
            UNUserNotificationCenter.current().setNotificationCategories([category])
        }
    
   
        // 4. THIS HANDLES THE USER'S INPUT OR CLICKS
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            if response.actionIdentifier == "REPLY_ACTION" {
                // Check if the user typed text
                if let textResponse = response as? UNTextInputNotificationResponse {
                    let userTyped = textResponse.userText
                    print("User typed: \(userTyped)")
                    
                    // You can take that user text and pass it directly to a script!
                    // runShellCommand("echo \(userTyped)")
                }
            } else if response.actionIdentifier == "DISMISS_ACTION" {
                print("User clicked the dismiss button.")
            }
            
            completionHandler()
        }
        
        // Forces the notification to show even if the app is focused in front
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound])
        }
    
    @objc func uninstallApp() {
            // We use AppleScript to ensure a smooth teardown sequence.
            // It unloads the launch agent, deletes the file, deletes the app, and kills the process.
            let uninstallScript = """
            do shell script "launchctl unload ~/Library/LaunchAgents/kha.prog.iNetShare.plist"
            do shell script "rm -f ~/Library/LaunchAgents/kha.prog.iNetShare.plist"
            do shell script "rm -rf /Applications/iNetShare.app"
            do shell script "killall iNetShare"
            """
            
            let alert = NSAlert()
            alert.messageText = "Are you sure?"
            alert.informativeText = "This will completely remove the app and its auto-launch settings from your system."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Remove Everything")
            
            // If the user clicks "Remove Everything" (the second button)
            if alert.runModal() == .alertSecondButtonReturn {
                if let scriptObject = NSAppleScript(source: uninstallScript) {
                    var error: NSDictionary?
                    scriptObject.executeAndReturnError(&error)
                    
                    if let err = error {
                        print("Error during uninstall: \(err)")
                    }
                }
            }
        }
    
   
    
    @objc func openWeb(){
        discoveryManager.broadcastEcho()
        /*var window: NSWindow!
        let rect = NSRect(x: 0, y: 0, width: 400, height: 500)
                
                window = NSWindow(
                    contentRect: rect,
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                
                window.title = "Terminal WebView"
                window.center()
                
                // Setup WKWebView
                let webView = WKWebView(frame: rect)
                if let url = URL(string: "https://google.com") {
                    webView.load(URLRequest(url: url))
                }
                
                window.contentView = webView
              window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)*/
    }
    // --- Actions ---
    
    @objc func openFinder() {
        // This opens the current user's home folder in Finder
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [NSHomeDirectory()]
        try? process.run()
    }
    
    
     func runScript(shellCommand:String) {
        var appleScriptSource = """
        do shell script "\(shellCommand)" with administrator privileges
        """
      
        if let password = promptForPassword(), !password.isEmpty  {
                print("Password: \(password)")
             appleScriptSource = """
            do shell script "\(shellCommand)" password \"\(password)\" with administrator privileges
            """
            }
       
      
        DispatchQueue.global(qos: .background).async  {
          
                    
                    // We wrap it in AppleScript so macOS knows to ask for your
                
                if let scriptObject = NSAppleScript(source: appleScriptSource) {
                    var error: NSDictionary?
                    scriptObject.executeAndReturnError(&error)
                    
                    if let err = error {
                        print("Error executing sudo command: \(err)")
                        self.sendNotification(message: "Error executing sudo command: \(err)")
                    } else {
                        print("Sudo command executed successfully!")
                        self.sendNotification(message:"Sudo command executed successfully!")
                    }
                }
        }
       
        }
    var pass:String?
    
    func promptForPassword() -> String? {
       // if let ps = pass{
         //   return ps
       // }
        if let savedPassword = UserDefaults.standard.string(forKey: "MacUserPassword"), !savedPassword.isEmpty {
            
                return savedPassword
            }
        let alert = NSAlert()
        alert.messageText = "Administrator Password Required"
        alert.informativeText = "Please enter your macOS account password to execute the netshare script."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
           
        alert.accessoryView = passwordField
        
        // Bring the dialog to the front
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            //pass = passwordField.stringValue
            let enteredPassword = passwordField.stringValue
            if !enteredPassword.isEmpty {
                        UserDefaults.standard.set(enteredPassword, forKey: "MacUserPassword")
                
                return enteredPassword
                    }
           
        }
        
        return nil
    }
    

  
    
    @objc func quitApp() {
        discoveryManager.stop()
        NSApp.terminate(nil)
    }
    
    @objc func handleService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
            guard let items = pboard.pasteboardItems else { return }
            
            for item in items {
                if let string = item.string(forType: .string) {
                    print("Received shared text from right-click: \(string)")
                    // You can now fire your terminal commands using this text string!
                }
            }
        }
    
}

import Foundation
import Network

class UDPDiscoveryManager {
    private var listener: NWListener?
    private var connection: NWConnection?
    private let udpPort: NWEndpoint.Port = 8888 // Choose any unused port
    private let queue = DispatchQueue(label: "com.netshare.udpQueue")
    
    // Structure for the JSON message we expect to receive
    struct DeviceInfo: Codable {
        let deviceName: String
        let status: String
    }
    
    // MARK: - Start Listening for JSON Messages
    func startListening() {
        do {
            listener = try NWListener(using: .udp, on: udpPort)
            
            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.handleIncomingConnection(newConnection)
            }
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("🟢 UDP Listener ready on port \(self.udpPort)")
                case .failed(let error):
                    print("❌ UDP Listener failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.start(queue: queue)
        } catch {
            print("❌ Failed to create UDP listener: \(error)")
        }
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                self?.parseJSONMessage(data)
            }
            // Keep listening for more data on this connection
            connection.cancel()
        }
    }
    
    private func parseJSONMessage(_ data: Data) {
        let decoder = JSONDecoder()
        do {
            let deviceInfo = try decoder.decode(DeviceInfo.self, from: data)
            print("👋 Found Device: \(deviceInfo.deviceName) | Status: \(deviceInfo.status)")
            
            // Post notification or update UI on the main thread
            DispatchQueue.main.async {
                // You can call your AppDelegate notification methods here!
            }
        } catch {
            // If it's not our JSON, maybe it's a raw string ping
            if let rawString = String(data: data, encoding: .utf8) {
                print("📩 Received raw UDP string: \(rawString)")
            }
        }
    }
    
    // MARK: - Broadcast 'Echo' to Local Devices
    func broadcastEcho() {
        // Use the special IPv4 broadcast address (or your specific subnet broadcast)
        let broadcastIP = IPv4Address("192.168.1.11")!
        let host = NWEndpoint.Host.ipv4(broadcastIP)
        let up: NWEndpoint.Port = 8881
        let connection = NWConnection(host: host, port: up, using: .udp)
        
        // Enable broadcasting on the connection
        let params = NWParameters.udp
        if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }
        
        connection.start(queue: queue)
        
        let message = "{\"deviceName\":\"MacController\", \"status\":\"scanning\"}"
        guard let data = message.data(using: .utf8) else { return }
        
        connection.send(content: data, completion: NWConnection.SendCompletion.contentProcessed { error in
            if let error = error {
                print("❌ Failed to broadcast echo: \(error)")
            } else {
                print("🚀 Broadcasted 'echo' to network.")
            }
            // Close connection after sending broadcast
            connection.cancel()
        })
    }
    
    func stop() {
        listener?.cancel()
    }
    
}


// Run the application silently without a dock icon
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()


