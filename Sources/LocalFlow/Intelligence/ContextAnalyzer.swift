import Foundation
import AppKit

public enum ApplicationCategory: String, Codable, CaseIterable, Sendable {
    case email = "Email"
    case workChat = "Work Chat"
    case personalChat = "Personal Chat"
    case code = "Code & Terminal"
    case document = "Document"
    case other = "Other"
}

public final class ContextAnalyzer: Sendable {
    public static let shared = ContextAnalyzer()
    
    public init() {}
    
    public func categorizeApplication(bundleId: String?) -> ApplicationCategory {
        guard let bid = bundleId?.lowercased() else { return .other }
        
        if bid.contains("mail") || bid.contains("outlook") {
            return .email
        }
        if bid.contains("slack") || bid.contains("teams") || bid.contains("discord") {
            return .workChat
        }
        if bid.contains("mobilesms") || bid.contains("messages") || bid.contains("whatsapp") || bid.contains("telegram") || bid.contains("signal") {
            return .personalChat
        }
        if bid.contains("xcode") || bid.contains("vscode") || bid.contains("terminal") || bid.contains("iterm") || bid.contains("sublime") {
            return .code
        }
        if bid.contains("pages") || bid.contains("word") || bid.contains("notion") || bid.contains("obsidian") || bid.contains("notes") {
            return .document
        }
        
        return .other
    }
}
