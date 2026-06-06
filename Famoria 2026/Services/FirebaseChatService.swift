import Foundation
import os
import FirebaseFirestore

final class FirebaseChatService {
    private let db = Firestore.firestore()

    // MARK: - Collection References

    private var chatsRef: CollectionReference {
        db.collection("chats")
    }

    private func messagesRef(chatId: String) -> CollectionReference {
        chatsRef.document(chatId).collection("messages")
    }

    // MARK: - Fetch

    func fetchChats(forUserId userId: String) async throws -> [Chat] {
        let snapshot = try await chatsRef
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()

        return snapshot.documents.compactMap { parseChat(from: $0) }
            .sorted { ($0.lastMessage?.timestamp ?? .distantPast) > ($1.lastMessage?.timestamp ?? .distantPast) }
    }

    func fetchMessages(chatId: String, limit: Int = 50) async throws -> [ChatMessage] {
        let snapshot = try await messagesRef(chatId: chatId)
            .order(by: "timestamp", descending: false)
            .limit(toLast: limit)
            .getDocuments()

        return snapshot.documents.compactMap { parseMessage(from: $0, chatId: chatId) }
    }

    // MARK: - Send

    func sendMessage(chatId: String, senderId: String, senderName: String, content: String, replyTo: ChatMessage? = nil) async throws -> ChatMessage {
        let messageId = UUID().uuidString
        let timestamp = Date()

        var messageData: [String: Any] = [
            "id": messageId,
            "senderId": senderId,
            "senderName": senderName,
            "content": content,
            "timestamp": Timestamp(date: timestamp),
            "isRead": false,
            "isSystem": false,
            "messageType": "text",
            "reactions": [],
            "deliveredAt": Timestamp(date: timestamp)
        ]

        if let reply = replyTo {
            messageData["replyToId"] = reply.id
            messageData["replyToContent"] = String(reply.content.prefix(100))
            messageData["replyToSenderName"] = reply.senderName
        }

        try await messagesRef(chatId: chatId).document(messageId).setData(messageData)

        // Update the chat's last message info
        try await chatsRef.document(chatId).updateData([
            "lastMessageContent": content,
            "lastMessageSenderName": senderName,
            "lastMessageTimestamp": Timestamp(date: timestamp)
        ])

        return ChatMessage(
            id: messageId,
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            timestamp: timestamp,
            isRead: false,
            isSystem: false,
            messageType: .text,
            replyToId: replyTo?.id,
            replyToContent: replyTo.map { String($0.content.prefix(100)) },
            replyToSenderName: replyTo?.senderName,
            deliveredAt: timestamp
        )
    }

    // MARK: - Send Image

    func sendImageMessage(chatId: String, senderId: String, senderName: String, imageURL: String) async throws -> ChatMessage {
        let messageId = UUID().uuidString
        let timestamp = Date()

        let messageData: [String: Any] = [
            "id": messageId,
            "senderId": senderId,
            "senderName": senderName,
            "content": "",
            "timestamp": Timestamp(date: timestamp),
            "isRead": false,
            "isSystem": false,
            "messageType": "image",
            "imageURL": imageURL,
            "reactions": [],
            "deliveredAt": Timestamp(date: timestamp)
        ]

        try await messagesRef(chatId: chatId).document(messageId).setData(messageData)

        try await chatsRef.document(chatId).updateData([
            "lastMessageContent": "Sent a photo",
            "lastMessageSenderName": senderName,
            "lastMessageTimestamp": Timestamp(date: timestamp)
        ])

        return ChatMessage(
            id: messageId,
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            content: "",
            timestamp: timestamp,
            isRead: false,
            isSystem: false,
            messageType: .image,
            imageURL: imageURL,
            deliveredAt: timestamp
        )
    }

    // MARK: - Send Voice Note

    /// Sends a voice-note message. `voiceURL` should already be a public
    /// Storage download URL (see ChatDetailView's upload helper).
    func sendVoiceMessage(
        chatId: String,
        senderId: String,
        senderName: String,
        voiceURL: String,
        duration: TimeInterval
    ) async throws -> ChatMessage {
        let messageId = UUID().uuidString
        let timestamp = Date()

        let messageData: [String: Any] = [
            "id": messageId,
            "senderId": senderId,
            "senderName": senderName,
            "content": "",
            "timestamp": Timestamp(date: timestamp),
            "isRead": false,
            "isSystem": false,
            "messageType": "voice",
            "voiceURL": voiceURL,
            "voiceDuration": duration,
            "reactions": [],
            "readBy": [senderId: Timestamp(date: timestamp)],
            "deliveredAt": Timestamp(date: timestamp)
        ]

        try await messagesRef(chatId: chatId).document(messageId).setData(messageData)
        try await chatsRef.document(chatId).updateData([
            "lastMessageContent": "Sent a voice note",
            "lastMessageSenderName": senderName,
            "lastMessageTimestamp": Timestamp(date: timestamp)
        ])

        return ChatMessage(
            id: messageId,
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            content: "",
            timestamp: timestamp,
            isRead: false,
            isSystem: false,
            messageType: .voice,
            voiceURL: voiceURL,
            voiceDuration: duration,
            deliveredAt: timestamp
        )
    }

    // MARK: - Reactions

    func addReaction(emoji: String, toMessage messageId: String, inChat chatId: String, userId: String, userName: String) async throws {
        let docRef = messagesRef(chatId: chatId).document(messageId)

        // Remove any existing reaction by this user, then add the new one
        let doc = try await docRef.getDocument()
        var reactions = (doc.data()?["reactions"] as? [[String: String]]) ?? []
        reactions.removeAll { $0["userId"] == userId }
        reactions.append(["emoji": emoji, "userId": userId, "userName": userName])

        try await docRef.updateData(["reactions": reactions])
    }

    // MARK: - Typing Indicators

    func setTyping(_ isTyping: Bool, userId: String, chatId: String) async throws {
        if isTyping {
            try await chatsRef.document(chatId).updateData([
                "typingUsers": FieldValue.arrayUnion([userId])
            ])
        } else {
            try await chatsRef.document(chatId).updateData([
                "typingUsers": FieldValue.arrayRemove([userId])
            ])
        }
    }

    // MARK: - Mark as Read

    func markMessagesAsRead(chatId: String, userId: String) async throws {
        let snapshot = try await messagesRef(chatId: chatId)
            .whereField("senderId", isNotEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.updateData([
                "isRead": true,
                "readAt": Timestamp(date: Date())
            ], forDocument: doc.reference)
        }

        // Reset unread count
        batch.updateData(["unreadCount": 0], forDocument: chatsRef.document(chatId))

        try await batch.commit()
    }

    // MARK: - Create Chats

    func createGroupChat(creatorId: String, participantIds: [String], participantNames: [String: String], name: String) async throws -> Chat {
        let chatId = UUID().uuidString
        let allIds = ([creatorId] + participantIds).uniqued()

        let participants = allIds.map { uid in
            ChatParticipant(
                id: uid,
                name: participantNames[uid] ?? "User",
                email: "",
                avatarURL: nil
            )
        }

        let chatData: [String: Any] = [
            "id": chatId,
            "name": name,
            "participantIds": allIds,
            "participants": participants.map { [
                "id": $0.id,
                "name": $0.name,
                "email": $0.email,
                "avatarURL": $0.avatarURL as Any
            ] },
            "unreadCount": 0,
            "typingUsers": [],
            "lastMessageContent": "",
            "lastMessageSenderName": "",
            "lastMessageTimestamp": Timestamp(date: Date()),
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await chatsRef.document(chatId).setData(chatData)

        // Add a system message
        let systemMsgId = UUID().uuidString
        let creatorName = participantNames[creatorId] ?? "Someone"
        try await messagesRef(chatId: chatId).document(systemMsgId).setData([
            "id": systemMsgId,
            "senderId": creatorId,
            "senderName": creatorName,
            "content": "\(creatorName) created the group \"\(name)\"",
            "timestamp": Timestamp(date: Date()),
            "isRead": true,
            "isSystem": true,
            "messageType": "system",
            "reactions": []
        ])

        return Chat(id: chatId, name: name, participants: participants, lastMessage: nil, unreadCount: 0)
    }

    func createDirectChat(userId1: String, userName1: String, userId2: String, userName2: String) async throws -> Chat {
        // Check if a DM already exists between these two users
        let existing = try await chatsRef
            .whereField("participantIds", arrayContains: userId1)
            .getDocuments()

        for doc in existing.documents {
            let data = doc.data()
            if let ids = data["participantIds"] as? [String],
               ids.contains(userId2),
               ids.count == 2,
               data["name"] == nil {
                if let chat = parseChat(from: doc) {
                    return chat
                }
            }
        }

        let chatId = UUID().uuidString
        let participants = [
            ChatParticipant(id: userId1, name: userName1, email: "", avatarURL: nil),
            ChatParticipant(id: userId2, name: userName2, email: "", avatarURL: nil)
        ]

        let chatData: [String: Any] = [
            "id": chatId,
            "participantIds": [userId1, userId2],
            "participants": participants.map { [
                "id": $0.id,
                "name": $0.name,
                "email": $0.email,
                "avatarURL": $0.avatarURL as Any
            ] },
            "unreadCount": 0,
            "typingUsers": [],
            "lastMessageContent": "",
            "lastMessageSenderName": "",
            "lastMessageTimestamp": Timestamp(date: Date()),
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await chatsRef.document(chatId).setData(chatData)

        return Chat(id: chatId, name: nil, participants: participants, lastMessage: nil, unreadCount: 0)
    }

    // MARK: - Real-time Observers

    func observeChats(forUserId userId: String, onChange: @escaping ([Chat]) -> Void) -> ListenerRegistration {
        chatsRef
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Log.chat.error("observeChats failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let self, let documents = snapshot?.documents else { return }
                let chats = documents.compactMap { self.parseChat(from: $0) }
                    .sorted { ($0.lastMessage?.timestamp ?? .distantPast) > ($1.lastMessage?.timestamp ?? .distantPast) }
                onChange(chats)
            }
    }

    func observeMessages(chatId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        messagesRef(chatId: chatId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Log.chat.error("observeMessages failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let self, let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                let messages = documents.compactMap { self.parseMessage(from: $0, chatId: chatId) }
                onChange(messages)
            }
    }

    // MARK: - Delete

    func deleteMessage(messageId: String, chatId: String) async throws {
        try await messagesRef(chatId: chatId).document(messageId).delete()
    }

    func deleteChat(chatId: String) async throws {
        let messagesSnapshot = try await messagesRef(chatId: chatId).getDocuments()
        let batch = db.batch()
        for doc in messagesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(chatsRef.document(chatId))
        try await batch.commit()
    }

    // MARK: - Parsing Helpers

    private func parseChat(from doc: DocumentSnapshot) -> Chat? {
        let data = doc.data() ?? [:]
        let id = data["id"] as? String ?? doc.documentID
        let name = data["name"] as? String
        let unreadCount = data["unreadCount"] as? Int ?? 0
        let typingUsers = data["typingUsers"] as? [String] ?? []

        let participantsData = data["participants"] as? [[String: Any]] ?? []
        let participants = participantsData.compactMap { p -> ChatParticipant? in
            guard let pid = p["id"] as? String,
                  let pname = p["name"] as? String else { return nil }
            return ChatParticipant(
                id: pid,
                name: pname,
                email: p["email"] as? String ?? "",
                avatarURL: p["avatarURL"] as? String
            )
        }

        var lastMessage: ChatMessage? = nil
        if let content = data["lastMessageContent"] as? String, !content.isEmpty,
           let senderName = data["lastMessageSenderName"] as? String,
           let ts = data["lastMessageTimestamp"] as? Timestamp {
            lastMessage = ChatMessage(
                id: "last",
                chatId: id,
                senderId: "",
                senderName: senderName,
                content: content,
                timestamp: ts.dateValue(),
                isRead: true,
                isSystem: false
            )
        }

        return Chat(
            id: id,
            name: name,
            participants: participants,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            typingUsers: typingUsers
        )
    }

    private func parseMessage(from doc: DocumentSnapshot, chatId: String) -> ChatMessage? {
        let data = doc.data() ?? [:]
        guard let id = data["id"] as? String ?? Optional(doc.documentID),
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let content = data["content"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }

        let reactionsData = data["reactions"] as? [[String: String]] ?? []
        let reactions = reactionsData.compactMap { r -> MessageReaction? in
            guard let emoji = r["emoji"],
                  let uid = r["userId"],
                  let uname = r["userName"] else { return nil }
            return MessageReaction(emoji: emoji, userId: uid, userName: uname)
        }

        let typeStr = data["messageType"] as? String ?? "text"
        let messageType = MessageType(rawValue: typeStr) ?? .text

        return ChatMessage(
            id: id,
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            timestamp: timestamp.dateValue(),
            isRead: data["isRead"] as? Bool ?? false,
            isSystem: data["isSystem"] as? Bool ?? false,
            messageType: messageType,
            imageURL: data["imageURL"] as? String,
            voiceURL: data["voiceURL"] as? String,
            voiceDuration: data["voiceDuration"] as? TimeInterval,
            reactions: reactions,
            replyToId: data["replyToId"] as? String,
            replyToContent: data["replyToContent"] as? String,
            replyToSenderName: data["replyToSenderName"] as? String,
            deliveredAt: (data["deliveredAt"] as? Timestamp)?.dateValue(),
            readAt: (data["readAt"] as? Timestamp)?.dateValue(),
            readBy: Self.decodeReadBy(data["readBy"])
        )
    }

    /// Decode a `readBy` map of `{userId: Timestamp}` into a Swift
    /// dictionary of dates.
    private static func decodeReadBy(_ raw: Any?) -> [String: Date] {
        guard let dict = raw as? [String: Any] else { return [:] }
        var result: [String: Date] = [:]
        for (uid, value) in dict {
            if let ts = value as? Timestamp {
                result[uid] = ts.dateValue()
            } else if let d = value as? Date {
                result[uid] = d
            }
        }
        return result
    }

    /// Marks the message as read by `userId` and stamps `readBy.{userId}`
    /// with the current server time. Used by ChatDetailView when a
    /// message becomes visible.
    func markMessageRead(messageId: String, chatId: String, userId: String) async {
        do {
            try await messagesRef(chatId: chatId).document(messageId).updateData([
                "readBy.\(userId)": Timestamp(date: Date())
            ])
        } catch {
            // Non-fatal; a missing read receipt isn't worth surfacing.
            Log.chat.debug("markMessageRead failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Array Extension

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
