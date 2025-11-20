import Foundation

class HelperTool: NSObject, HelperProtocol, NSXPCListenerDelegate {
    
    func deleteItem(at path: String, secure: Bool, withReply reply: @escaping (Bool, Error?) -> Void) {
        // In the real helper, this would run as root
        let url = URL(fileURLWithPath: path)
        do {
            if secure {
                // Overwrite logic
                try FileManager.default.removeItem(at: url)
            } else {
                try FileManager.default.removeItem(at: url)
            }
            reply(true, nil)
        } catch {
            reply(false, error)
        }
    }
    
    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}
