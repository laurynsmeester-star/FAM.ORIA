import Foundation

// MARK: - Chat Model (Group or DM)
struct Chat: Identifiable, Codable, Equatable {
    let id: String
    var name: String? // nil for DM
    var participants: [ChatParticipant]
    var lastMessage: ChatMessage?
    var unreadCount: Int = 0
    var typingUsers: [String] = [] // user IDs currently typing

    var isGroup: Bool { name != nil }

    private enum CodingKeys: String, CodingKey {
        case id, name, participants, lastMessage, unreadCount, typingUsers
    }
}

struct ChatParticipant: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let email: String
    let avatarURL: String?
}

// MARK: - Message Types

enum MessageType: String, Codable, Equatable {
    case text
    case image
    case system // "Lauryn added John", etc.
}

struct MessageReaction: Codable, Equatable {
    let emoji: String
    let userId: String
    let userName: String
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    var isRead: Bool
    let isSystem: Bool
    var messageType: MessageType = .text
    var imageURL: String? = nil
    var reactions: [MessageReaction] = []
    var replyToId: String? = nil
    var replyToContent: String? = nil
    var replyToSenderName: String? = nil
    var deliveredAt: Date? = nil
    var readAt: Date? = nil
}
