//
//  AIImportAssistant.swift
//  Famoria 2026
//
//  Heuristic-first import organizer. Parses messy text into structured
//  recipes / suggests document categories + tags / cleans up ingredient
//  lists. Designed as a protocol so you can later plug in a real LLM
//  (Claude / OpenAI / on-device CoreML) without touching the views.
//
//  The default implementation is a dependency-free heuristic so the
//  feature works offline today.
//

import Foundation

// MARK: - Public protocol

@MainActor
public protocol AIImportAssistant {
    /// Parse free-form text (pasted or extracted from a file) into a
    /// best-guess Recipe.
    func organizeRecipe(from rawText: String) async -> FamilyRecipe

    /// Suggest category + tags + a cleaned title for an imported document
    /// using its filename, file type, and any extracted text snippet.
    func organizeDocument(
        filename: String,
        fileType: DocumentFileType,
        textSnippet: String?
    ) async -> DocumentSuggestion

    /// Clean up a single ingredient line: trim, deduplicate units, normalize
    /// fractions ("1/2" → "½"), capitalize first character.
    func cleanIngredient(_ line: String) -> String
}

public struct DocumentSuggestion: Equatable {
    public var title: String
    public var category: DocumentCategory
    public var tags: [String]
    public init(title: String, category: DocumentCategory, tags: [String]) {
        self.title = title
        self.category = category
        self.tags = tags
    }
}

// MARK: - Heuristic default

@MainActor
public final class HeuristicAIImportAssistant: AIImportAssistant {
    public init() {}

    // MARK: Recipe parsing

    public func organizeRecipe(from rawText: String) async -> FamilyRecipe {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return FamilyRecipe(title: "Untitled Recipe") }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Title = first non-trivial line, or first numbered line's parent header.
        let title = lines.first ?? "Untitled Recipe"

        // Detect labeled sections.
        var ingredients: [String] = []
        var instructionsLines: [String] = []
        var story: String = ""
        var section: Section = .unknown
        var prepTime = ""
        var servings: Int? = nil
        var author = ""

        for raw in lines.dropFirst() {
            let lower = raw.lowercased()

            if let match = lower.range(of: #"(?:from|by)\s+"#, options: .regularExpression),
               author.isEmpty {
                author = String(raw[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                continue
            }
            if let n = Self.matchPrepTime(lower) { prepTime = n; continue }
            if let s = Self.matchServings(lower) { servings = s; continue }

            // Section headers
            if lower.contains("ingredient") { section = .ingredients; continue }
            if lower.contains("instruction") || lower.contains("direction") || lower.contains("method") || lower.contains("steps") {
                section = .instructions; continue
            }
            if lower.contains("story") || lower.contains("about") || lower.contains("note") {
                section = .story; continue
            }

            switch section {
            case .ingredients:
                ingredients.append(cleanIngredient(raw))
            case .instructions:
                instructionsLines.append(raw)
            case .story:
                story.append(story.isEmpty ? raw : "\n\(raw)")
            case .unknown:
                // Bullet/number → ingredient. Otherwise treat as instruction.
                if Self.looksLikeBullet(raw) {
                    ingredients.append(cleanIngredient(raw))
                } else if Self.looksLikeStep(raw) {
                    instructionsLines.append(raw)
                } else {
                    // Unlabeled prose — accumulate as story tail.
                    story.append(story.isEmpty ? raw : "\n\(raw)")
                }
            }
        }

        let category = Self.guessCategory(from: title + " " + ingredients.joined(separator: " "))
        let instructions = instructionsLines
            .enumerated()
            .map { idx, line in
                Self.looksLikeStep(line) ? line : "\(idx + 1). \(line)"
            }
            .joined(separator: "\n")

        return FamilyRecipe(
            title: title,
            author: author,
            category: category,
            ingredients: ingredients,
            instructions: instructions,
            story: story,
            prepTime: prepTime,
            servings: servings
        )
    }

    // MARK: Document organizing

    public func organizeDocument(
        filename: String,
        fileType: DocumentFileType,
        textSnippet: String?
    ) async -> DocumentSuggestion {
        let cleanedTitle = Self.cleanTitle(from: filename)
        let combined = (cleanedTitle + " " + (textSnippet ?? "")).lowercased()

        let category: DocumentCategory
        switch true {
        case combined.contains(anyOf: ["medical", "doctor", "rx", "prescription", "vaccine", "lab"]): category = .medical
        case combined.contains(anyOf: ["legal", "contract", "agreement", "deed", "will", "trust", "court"]): category = .legal
        case combined.contains(anyOf: ["bank", "tax", "1099", "w-2", "w2", "invoice", "receipt", "statement", "budget"]): category = .financial
        case combined.contains(anyOf: ["recipe", "ingredient", "cook", "bake"]): category = .recipes
        case combined.contains(anyOf: ["school", "report card", "transcript", "homework", "syllabus"]): category = .education
        case fileType == .image: category = .photos
        case combined.contains(anyOf: ["family", "tree", "ancestry", "genealogy"]): category = .family
        default: category = .other
        }

        let tags = Self.extractTags(from: combined)
        return DocumentSuggestion(title: cleanedTitle, category: category, tags: tags)
    }

    // MARK: Ingredient cleaning

    public func cleanIngredient(_ line: String) -> String {
        var s = line.trimmingCharacters(in: CharacterSet(charactersIn: "•-*•·● 0123456789.) "))
        s = s.replacingOccurrences(of: "1/2", with: "½")
        s = s.replacingOccurrences(of: "1/4", with: "¼")
        s = s.replacingOccurrences(of: "3/4", with: "¾")
        s = s.replacingOccurrences(of: "1/3", with: "⅓")
        s = s.replacingOccurrences(of: "2/3", with: "⅔")
        s = s.replacingOccurrences(of: "1/8", with: "⅛")
        // Normalize spaces
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // Capitalize first character
        if let first = s.first { s = first.uppercased() + s.dropFirst() }
        return s
    }

    // MARK: - Helpers

    private enum Section { case unknown, ingredients, instructions, story }

    private static func looksLikeBullet(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.first.map { "•-*·●".contains($0) } == true
            || trimmed.range(of: #"^\d+\s*(?:cups?|tsp|tbsp|oz|lb|grams?|kg|ml|l|cloves?)\b"#,
                              options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func looksLikeStep(_ s: String) -> Bool {
        s.range(of: #"^\d+[\.\)]"#, options: .regularExpression) != nil
            || s.lowercased().hasPrefix("step ")
    }

    private static func matchPrepTime(_ lower: String) -> String? {
        if let r = lower.range(of: #"(?:prep|cook|total)\s*time:?\s*[\d\sa-z]+"#,
                                options: .regularExpression) {
            return String(lower[r])
                .replacingOccurrences(of: #"^(?:prep|cook|total)\s*time:?\s*"#,
                                      with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func matchServings(_ lower: String) -> Int? {
        if let r = lower.range(of: #"(?:serves|servings?):?\s*(\d+)"#, options: .regularExpression) {
            let snippet = String(lower[r])
            if let n = snippet.split(whereSeparator: { !$0.isNumber }).last, let v = Int(n) {
                return v
            }
        }
        return nil
    }

    private static func guessCategory(from blob: String) -> RecipeCategory {
        let lower = blob.lowercased()
        if lower.contains(anyOf: ["cake", "cookie", "pie", "ice cream", "brownie", "pudding"]) { return .dessert }
        if lower.contains(anyOf: ["coffee", "tea", "smoothie", "cocktail", "punch"]) { return .beverage }
        if lower.contains(anyOf: ["pancake", "waffle", "egg", "bacon", "oatmeal"]) { return .breakfast }
        if lower.contains(anyOf: ["salad", "soup", "wrap", "sandwich"]) { return .lunch }
        if lower.contains(anyOf: ["holiday", "thanksgiving", "christmas", "easter", "passover"]) { return .holidaySpecial }
        if lower.contains(anyOf: ["pasta", "chicken", "steak", "roast", "casserole", "stew"]) { return .dinner }
        return .mainCourse
    }

    private static func cleanTitle(from filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        return base
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .capitalized
            .trimmingCharacters(in: .whitespaces)
    }

    private static func extractTags(from lower: String) -> [String] {
        var tags: Set<String> = []
        let candidates = ["family", "kids", "school", "work", "trip", "vacation",
                          "wedding", "birthday", "tax", "invoice", "receipt"]
        for c in candidates where lower.contains(c) { tags.insert(c) }
        return Array(tags).sorted()
    }
}

// MARK: - String helper

private extension String {
    func contains(anyOf needles: [String]) -> Bool {
        for n in needles where range(of: n) != nil { return true }
        return false
    }
}
