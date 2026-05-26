//
//  Logger+Famoria.swift
//  Famoria 2026
//
//  Centralized os.Logger categories for structured logging.
//  Use these everywhere instead of `print()` so logs are filterable
//  in Console.app and respect privacy redaction in production.
//

import Foundation
import os

enum Log {
    private static let subsystem = "com.famoria.app"

    static let auth          = Logger(subsystem: subsystem, category: "auth")
    static let chat          = Logger(subsystem: subsystem, category: "chat")
    static let content       = Logger(subsystem: subsystem, category: "content")
    static let family        = Logger(subsystem: subsystem, category: "family")
    static let familyTree    = Logger(subsystem: subsystem, category: "familyTree")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let celebration   = Logger(subsystem: subsystem, category: "celebration")
    static let calendar      = Logger(subsystem: subsystem, category: "calendar")
    static let tasks         = Logger(subsystem: subsystem, category: "tasks")
    static let appState      = Logger(subsystem: subsystem, category: "appState")
    static let app           = Logger(subsystem: subsystem, category: "app")
    static let albums        = Logger(subsystem: subsystem, category: "albums")
    static let wishlist      = Logger(subsystem: subsystem, category: "wishlist")
    static let health        = Logger(subsystem: subsystem, category: "health")
    static let journal       = Logger(subsystem: subsystem, category: "journal")
}
