//
//  MoreModels.swift
//  Famoria 2026
//
//  Data models for Documents and Recipes.
//  Replaces the inline `FamilyDocument` / `FamilyRecipe` structs from your
//  previous DocumentsView.swift and RecipesView.swift — keep these names,
//  just delete those inline definitions when you drop the new views in.
//

import Foundation
import SwiftUI
import Combine
@preconcurrency import FirebaseFirestore

// MARK: - Documents

public enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case family, legal, medical, financial, photos, recipes, education, other
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
    public var emoji: String {
        switch self {
        case .family:    return "👨‍👩‍👧‍👦"
        case .legal:     return "⚖️"
        case .medical:   return "🏥"
        case .financial: return "💰"
        case .photos:    return "📸"
        case .recipes:   return "🍳"
        case .education: return "🎓"
        case .other:     return "📄"
        }
    }
    public var systemImage: String {
        switch self {
        case .family:    return "person.3.fill"
        case .legal:     return "building.columns.fill"
        case .medical:   return "cross.case.fill"
        case .financial: return "dollarsign.circle.fill"
        case .photos:    return "photo.fill"
        case .recipes:   return "fork.knife"
        case .education: return "graduationcap.fill"
        case .other:     return "doc.text.fill"
        }
    }
    public var color: Color {
        switch self {
        case .family:    return .pink
        case .legal:     return .blue
        case .medical:   return .red
        case .financial: return .green
        case .photos:    return .purple
        case .recipes:   return .orange
        case .education: return .indigo
        case .other:     return .gray
        }
    }
}

public enum DocumentFileType: String, Codable, CaseIterable, Identifiable {
    case pdf, doc, image, spreadsheet, text, other
    public var id: String { rawValue }
    public var systemImage: String {
        switch self {
        case .pdf:         return "doc.richtext.fill"
        case .doc:         return "doc.text.fill"
        case .image:       return "photo.fill"
        case .spreadsheet: return "tablecells.fill"
        case .text:        return "text.alignleft"
        case .other:       return "doc.fill"
        }
    }

    /// Best-guess from a file URL's extension / UTI.
    public static func detect(from url: URL) -> DocumentFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "doc", "docx", "rtf", "pages": return .doc
        case "png", "jpg", "jpeg", "heic", "gif", "webp": return .image
        case "xls", "xlsx", "csv", "tsv", "numbers": return .spreadsheet
        case "txt", "md": return .text
        default: return .other
        }
    }
}

/// Who can see / open a document.
public enum DocumentVisibility: String, Codable, CaseIterable, Identifiable {
    case privateOnly = "private"   // only the uploader
    case admins                    // uploader + family admins/owners
    case family                    // everyone in the family
    case specific                  // only `allowedMembers`
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .privateOnly: return "Only me"
        case .admins:      return "Admins only"
        case .family:      return "Whole family"
        case .specific:    return "Specific members"
        }
    }
    public var systemImage: String {
        switch self {
        case .privateOnly: return "lock.fill"
        case .admins:      return "person.badge.shield.checkmark.fill"
        case .family:      return "person.3.fill"
        case .specific:    return "person.crop.circle.badge.questionmark.fill"
        }
    }
}

public struct FamilyDocument: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var notes: String
    /// Optional original URL (e.g. iCloud / remote).
    public var fileURL: URL?
    /// File copied into app's Documents directory.
    public var localFilename: String?
    public var fileType: DocumentFileType
    public var category: DocumentCategory
    public var tags: [String]
    public var uploadedBy: String
    public var createdDate: Date

    // Privacy
    public var visibility: DocumentVisibility
    public var allowedMembers: [String]

    // Collaboration
    public var linkedEventId: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String = "",
        fileURL: URL? = nil,
        localFilename: String? = nil,
        fileType: DocumentFileType = .other,
        category: DocumentCategory = .other,
        tags: [String] = [],
        uploadedBy: String,
        createdDate: Date = Date(),
        visibility: DocumentVisibility = .family,
        allowedMembers: [String] = [],
        linkedEventId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.fileURL = fileURL
        self.localFilename = localFilename
        self.fileType = fileType
        self.category = category
        self.tags = tags
        self.uploadedBy = uploadedBy
        self.createdDate = createdDate
        self.visibility = visibility
        self.allowedMembers = allowedMembers
        self.linkedEventId = linkedEventId
    }

    /// Returns true if `viewer` can see this document.
    public func canBeViewed(by viewer: String, isAdmin: Bool) -> Bool {
        switch visibility {
        case .privateOnly: return viewer == uploadedBy
        case .admins:      return viewer == uploadedBy || isAdmin
        case .family:      return true
        case .specific:    return viewer == uploadedBy || allowedMembers.contains(viewer)
        }
    }
}

public struct DocumentComment: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var documentId: String
    public var authorName: String
    public var content: String
    public var createdDate: Date
    public var isResolved: Bool
    public var replyToId: String?

    public init(
        id: String = UUID().uuidString,
        documentId: String,
        authorName: String,
        content: String,
        createdDate: Date = Date(),
        isResolved: Bool = false,
        replyToId: String? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.authorName = authorName
        self.content = content
        self.createdDate = createdDate
        self.isResolved = isResolved
        self.replyToId = replyToId
    }
}

// MARK: - Recipes

public enum RecipeCategory: String, Codable, CaseIterable, Identifiable {
    case appetizer
    case mainCourse      = "main course"
    case dessert
    case sideDish        = "side dish"
    case breakfast
    case lunch
    case dinner
    case beverage
    case snack
    case holidaySpecial  = "holiday special"
    case other

    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }

    public var color: Color {
        switch self {
        case .appetizer:      return .orange
        case .mainCourse:     return .pink
        case .dessert:        return Color(red: 0.93, green: 0.28, blue: 0.60)
        case .sideDish:       return .green
        case .breakfast:      return Color(red: 0.96, green: 0.55, blue: 0.20)
        case .lunch:          return .yellow
        case .dinner:         return .indigo
        case .beverage:       return .blue
        case .snack:          return .mint
        case .holidaySpecial: return .red
        case .other:          return .gray
        }
    }

    public var systemImage: String {
        switch self {
        case .breakfast:      return "sun.horizon.fill"
        case .lunch:          return "takeoutbag.and.cup.and.straw.fill"
        case .dinner:         return "moon.stars.fill"
        case .dessert:        return "birthday.cake.fill"
        case .snack:          return "carrot.fill"
        case .beverage:       return "cup.and.saucer.fill"
        case .appetizer:      return "leaf.fill"
        case .mainCourse:     return "fork.knife"
        case .sideDish:       return "circle.grid.2x2.fill"
        case .holidaySpecial: return "gift.fill"
        case .other:          return "fork.knife"
        }
    }
}

public struct FamilyRecipe: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var author: String
    public var category: RecipeCategory
    public var imageURL: URL?
    public var localImageFilename: String?
    public var ingredients: [String]
    public var instructions: String
    public var story: String
    public var prepTime: String
    public var servings: Int?
    public var createdDate: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        author: String = "",
        category: RecipeCategory = .dinner,
        imageURL: URL? = nil,
        localImageFilename: String? = nil,
        ingredients: [String] = [],
        instructions: String = "",
        story: String = "",
        prepTime: String = "",
        servings: Int? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.category = category
        self.imageURL = imageURL
        self.localImageFilename = localImageFilename
        self.ingredients = ingredients
        self.instructions = instructions
        self.story = story
        self.prepTime = prepTime
        self.servings = servings
        self.createdDate = createdDate
    }
}

// MARK: - Stores
//
// In-memory ObservableObject stores so the views compile and run today.
// Replace bodies with calls to your FirebaseFamilyService when ready —
// the public API stays identical.

// MARK: - Local JSON Persistence Helper

enum LocalStore {
    static let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    static func save<T: Encodable>(_ items: T, filename: String) {
        let url = docsDir.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        let url = docsDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}

@MainActor
public final class DocumentsStore: ObservableObject {

    @Published public var documents: [FamilyDocument] = []
    @Published public var comments: [DocumentComment] = []

    private let db = Firestore.firestore()
    private var docsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?

    public init() {}

    public func startListening() {
        docsListener?.remove()
        commentsListener?.remove()

        docsListener = db.collection("famoria_documents")
            .order(by: "createdDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                self.documents = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(FamilyDocument.self, from: data)
                }
            }

        commentsListener = db.collection("famoria_doc_comments")
            .order(by: "createdDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                self.comments = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(DocumentComment.self, from: data)
                }
            }
    }

    public func stopListening() {
        docsListener?.remove()
        commentsListener?.remove()
        docsListener = nil
        commentsListener = nil
    }

    public func add(_ doc: FamilyDocument) {
        try? db.collection("famoria_documents").document(doc.id).setData(from: doc)
    }

    public func remove(_ id: String) {
        db.collection("famoria_documents").document(id).delete()
        db.collection("famoria_doc_comments").whereField("documentId", isEqualTo: id).getDocuments { [db] snapshot, _ in
            let batch = db.batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit()
        }
    }

    public func update(_ doc: FamilyDocument) {
        try? db.collection("famoria_documents").document(doc.id).setData(from: doc, merge: true)
    }

    public func addComment(_ c: DocumentComment) {
        try? db.collection("famoria_doc_comments").document(c.id).setData(from: c)
    }

    public func toggleResolve(_ id: String) {
        if let i = comments.firstIndex(where: { $0.id == id }) {
            let newValue = !comments[i].isResolved
            db.collection("famoria_doc_comments").document(id).updateData(["isResolved": newValue])
        }
    }

    public func comments(for docId: String) -> [DocumentComment] {
        comments.filter { $0.documentId == docId }.sorted { $0.createdDate < $1.createdDate }
    }
}

@MainActor
public final class RecipesStore: ObservableObject {
    @Published public var recipes: [FamilyRecipe] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    public init() {}

    public func startListening() {
        listener?.remove()
        listener = db.collection("famoria_recipes")
            .order(by: "createdDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                self.recipes = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(FamilyRecipe.self, from: data)
                }
            }
    }

    public func stopListening() {
        listener?.remove()
        listener = nil
    }

    public func upsert(_ r: FamilyRecipe) {
        try? db.collection("famoria_recipes").document(r.id).setData(from: r)
    }

    public func remove(_ id: String) {
        db.collection("famoria_recipes").document(id).delete()
    }
}

