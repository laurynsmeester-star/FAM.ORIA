//
//  FamoriaAlbumModels.swift
//  Famoria Update 2026
//
//  Data models for the Photo Albums feature.
//  Mirrors the Album + Photo schema from the web reference.
//
//  Requirements: FirebaseFirestore (already in project)
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Album Category

enum AlbumCategory: String, CaseIterable, Codable {
    case holiday  = "holiday"
    case trip     = "trip"
    case event    = "event"
    case everyday = "everyday"

    var displayName: String {
        switch self {
        case .holiday:  return "Holiday"
        case .trip:     return "Trip"
        case .event:    return "Event"
        case .everyday: return "Everyday"
        }
    }

    var emoji: String {
        switch self {
        case .holiday:  return "\u{1F384}"
        case .trip:     return "\u{2708}\u{FE0F}"
        case .event:    return "\u{1F389}"
        case .everyday: return "\u{1F4F7}"
        }
    }

    /// Foreground text/icon color for category badge
    var badgeForeground: Color {
        switch self {
        case .holiday:  return Color(red: 0.83, green: 0.10, blue: 0.10)
        case .trip:     return Color(red: 0.08, green: 0.39, blue: 0.85)
        case .event:    return Color(red: 0.53, green: 0.10, blue: 0.85)
        case .everyday: return Color(red: 0.06, green: 0.58, blue: 0.32)
        }
    }

    /// Background tint for category badge
    var badgeBackground: Color {
        switch self {
        case .holiday:  return Color(red: 0.99, green: 0.91, blue: 0.91)
        case .trip:     return Color(red: 0.90, green: 0.94, blue: 0.99)
        case .event:    return Color(red: 0.95, green: 0.90, blue: 0.99)
        case .everyday: return Color(red: 0.90, green: 0.98, blue: 0.93)
        }
    }
}

// MARK: - Album

struct FamoriaAlbum: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    var title: String
    var category: AlbumCategory
    var date: Date?
    var albumDescription: String
    var coverImageURL: String?
    var photoCount: Int
    var createdAt: Date

    init(
        id: String? = nil,
        title: String,
        category: AlbumCategory = .event,
        date: Date? = nil,
        description: String = "",
        coverImageURL: String? = nil
    ) {
        self.id             = id
        self.title          = title
        self.category       = category
        self.date           = date
        self.albumDescription = description
        self.coverImageURL  = coverImageURL
        self.photoCount     = 0
        self.createdAt      = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case date
        case albumDescription = "description"
        case coverImageURL    = "cover_image_url"
        case photoCount       = "photo_count"
        case createdAt        = "created_at"
    }

    // Hashable conformance (required for NavigationStack path)
    static func == (lhs: FamoriaAlbum, rhs: FamoriaAlbum) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Media Type

/// Discriminator for `FamoriaPhoto` so the same docs collection can
/// hold both stills and video clips. Defaults to `.photo` so legacy
/// documents that don't carry the field decode cleanly.
enum FamoriaMediaType: String, Codable {
    case photo
    case video
}

// MARK: - Photo / Video

struct FamoriaPhoto: Identifiable, Codable {
    @DocumentID var id: String?

    var albumId: String
    /// For photos this is the still image URL. For videos it's a
    /// thumbnail used while loading; the playable file is `videoURL`.
    var imageURL: String
    /// Storage download URL for the playable video (nil for stills).
    var videoURL: String?
    /// Playback duration in seconds (videos only).
    var videoDuration: Double?
    var mediaType: FamoriaMediaType
    var caption: String
    var dateTaken: Date
    var createdAt: Date

    init(
        id: String? = nil,
        albumId: String,
        imageURL: String,
        videoURL: String? = nil,
        videoDuration: Double? = nil,
        mediaType: FamoriaMediaType = .photo,
        caption: String = "",
        dateTaken: Date = Date()
    ) {
        self.id            = id
        self.albumId       = albumId
        self.imageURL      = imageURL
        self.videoURL      = videoURL
        self.videoDuration = videoDuration
        self.mediaType     = mediaType
        self.caption       = caption
        self.dateTaken     = dateTaken
        self.createdAt     = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case albumId       = "album_id"
        case imageURL      = "image_url"
        case videoURL      = "video_url"
        case videoDuration = "video_duration"
        case mediaType     = "media_type"
        case caption
        case dateTaken     = "date_taken"
        case createdAt     = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self._id           = try c.decode(DocumentID<String>.self, forKey: .id)
        self.albumId       = try c.decode(String.self, forKey: .albumId)
        self.imageURL      = try c.decode(String.self, forKey: .imageURL)
        self.videoURL      = try c.decodeIfPresent(String.self, forKey: .videoURL)
        self.videoDuration = try c.decodeIfPresent(Double.self, forKey: .videoDuration)
        self.mediaType     = (try? c.decode(FamoriaMediaType.self, forKey: .mediaType)) ?? .photo
        self.caption       = (try? c.decode(String.self, forKey: .caption)) ?? ""
        self.dateTaken     = try c.decode(Date.self, forKey: .dateTaken)
        self.createdAt     = try c.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - Brand Colors

extension Color {
    /// Rose-500 — matches the web app's primary gradient start
    static let famoriaRose   = Color(red: 0.953, green: 0.267, blue: 0.373)
    /// Violet-500 — matches the web app's primary gradient end
    static let famoriaViolet = Color(red: 0.549, green: 0.239, blue: 0.945)
}

extension LinearGradient {
    /// The rose → violet gradient used on primary buttons and accents
    static let famoriaPrimary = LinearGradient(
        colors: [.famoriaRose, .famoriaViolet],
        startPoint: .leading,
        endPoint: .trailing
    )
}
