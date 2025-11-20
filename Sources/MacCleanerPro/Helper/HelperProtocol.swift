import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func deleteItem(at path: String, secure: Bool, withReply reply: @escaping (Bool, Error?) -> Void)
    func getVersion(withReply reply: @escaping (String) -> Void)
}
