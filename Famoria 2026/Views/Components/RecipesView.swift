//
//  RecipesView.swift
//  Famoria 2026
//
//  Replaces the previous RecipesView.swift.
//
//  Adds:
//   • Card grid (image + category badge + author + prep / servings)
//   • Search + category tabs + sort menu
//   • Add / edit recipe form (PhotosPicker for the photo, ingredient chips)
//   • Detail sheet with full layout
//   • Import: pick a .json file (single or array) OR paste text and let
//     `AIImportAssistant` parse it into structured ingredients/instructions
//   • Export: ShareLink to a JSON file written to a temp directory
//
//  IMPORTANT: delete the inline `FamilyRecipe` struct from your old file —
//  the canonical type now lives in MoreModels.swift.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

// MARK: - RecipesView

struct RecipesView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var store = RecipesStore()
    private let assistant: AIImportAssistant = HeuristicAIImportAssistant()

    @State private var filter: RecipeCategory? = nil
    @State private var sort: SortMode = .newest
    @State private var showAdd = false
    @State private var showImport = false
    @State private var showAIPasteImport = false
    @State private var editing: FamilyRecipe? = nil
    @State private var viewing: FamilyRecipe? = nil
    @State private var exportURL: URL? = nil
    @State private var showExportShare = false

    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "Newest", oldest = "Oldest", titleAZ = "Title A–Z", category = "Category"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Family Recipes")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarMenu }
                .sheet(isPresented: $showAdd) {
                    RecipeFormSheet(
                        store: store,
                        assistant: assistant,
                        defaultAuthor: appState.currentUser?.name ?? "",
                        editing: nil
                    )
                }
                .sheet(item: $editing) { recipe in
                    RecipeFormSheet(
                        store: store,
                        assistant: assistant,
                        defaultAuthor: appState.currentUser?.name ?? "",
                        editing: recipe
                    )
                }
                .sheet(item: $viewing) { recipe in
                    RecipeDetailSheet(
                        recipe: recipe,
                        onEdit: { editing = recipe },
                        onDelete: { store.remove(recipe.id) },
                        onExport: { exportSingle(recipe) }
                    )
                }
                .sheet(isPresented: $showAIPasteImport) {
                    PasteRecipeSheet(assistant: assistant) { parsed in
                        store.upsert(parsed)
                    }
                }
                .fileImporter(
                    isPresented: $showImport,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { handleJSONImport($0) }
                .sheet(isPresented: $showExportShare) {
                    if let url = exportURL {
                        ShareSheet(items: [url])
                    }
                }
                .onAppear { store.startListening() }
                .onDisappear { store.stopListening() }
                .alert(
                    "Couldn't save",
                    isPresented: Binding(
                        get: { store.errorMessage != nil },
                        set: { if !$0 { store.errorMessage = nil } }
                    ),
                    presenting: store.errorMessage
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                categoryTabs
                if filtered.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                        ForEach(filtered) { recipe in
                            RecipeCard(recipe: recipe) { viewing = recipe }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
    }

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Divider()
                Button { showAdd = true } label: {
                    Label("Add Recipe", systemImage: "plus")
                }
                Button { showImport = true } label: {
                    Label("Import from JSON", systemImage: "square.and.arrow.down")
                }
                Button { showAIPasteImport = true } label: {
                    Label("Paste & AI Organize", systemImage: "sparkles")
                }
                Divider()
                Button { exportAll() } label: {
                    Label("Export All", systemImage: "square.and.arrow.up.on.square")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", systemImage: "tray.full",
                     active: filter == nil, color: .orange) { filter = nil }
                ForEach(RecipeCategory.allCases) { cat in
                    Chip(title: cat.displayName, systemImage: cat.systemImage,
                         active: filter == cat, color: cat.color) {
                        filter = (filter == cat) ? nil : cat
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(store.recipes.isEmpty ? "No recipes yet" : "Nothing matches your filters")
                .font(.headline)
            if store.recipes.isEmpty {
                Text("Capture grandma's pie, the holiday roast, the secret sauce.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                HStack {
                    Button { showAdd = true } label: {
                        Label("Add Recipe", systemImage: "plus")
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    Button { showAIPasteImport = true } label: {
                        Label("Paste & Organize", systemImage: "sparkles")
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    // MARK: Filtering

    private var filtered: [FamilyRecipe] {
        var r = store.recipes
        if let f = filter { r = r.filter { $0.category == f } }
        switch sort {
        case .newest:   r.sort { $0.createdDate > $1.createdDate }
        case .oldest:   r.sort { $0.createdDate < $1.createdDate }
        case .titleAZ:  r.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .category: r.sort { $0.category.rawValue < $1.category.rawValue }
        }
        return r
    }

    // MARK: Import / Export

    private func handleJSONImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let src = urls.first else { return }
        let did = src.startAccessingSecurityScopedResource()
        defer { if did { src.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: src) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let many = try? decoder.decode([FamilyRecipe].self, from: data) {
            many.forEach { store.upsert($0) }
        } else if let one = try? decoder.decode(FamilyRecipe.self, from: data) {
            store.upsert(one)
        }
    }

    private func exportSingle(_ recipe: FamilyRecipe) {
        guard let url = writeJSON([recipe], filename: "\(recipe.title).json") else { return }
        exportURL = url
        showExportShare = true
    }

    private func exportAll() {
        guard let url = writeJSON(store.recipes, filename: "FamoriaRecipes.json") else { return }
        exportURL = url
        showExportShare = true
    }

    private func writeJSON(_ recipes: [FamilyRecipe], filename: String) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(recipes) else { return nil }
        let safe = filename.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe)
        try? data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Card

private struct RecipeCard: View {
    let recipe: FamilyRecipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Group {
                        if let url = recipe.imageURL, !url.isFileURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: placeholder
                                }
                            }
                        } else if let local = recipe.localImageFilename,
                                  let img = LocalImage.load(filename: local) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            placeholder
                        }
                    }
                    .frame(height: 110).frame(maxWidth: .infinity).clipped()

                    HStack {
                        Text(recipe.category.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(recipe.category.color))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !recipe.author.isEmpty {
                        Label(recipe.author, systemImage: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.pink)
                    }
                    HStack(spacing: 10) {
                        if !recipe.prepTime.isEmpty {
                            Label(recipe.prepTime, systemImage: "clock")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        if let s = recipe.servings {
                            Label("\(s)", systemImage: "person.2")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    if !recipe.story.isEmpty {
                        Text("\u{201C}\(recipe.story)\u{201D}")
                            .font(.caption2.italic())
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(10)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color.orange.opacity(0.18), Color.pink.opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: recipe.category.systemImage)
                .font(.system(size: 28))
                .foregroundColor(.orange)
        }
    }
}

// MARK: - Add / Edit form

private struct RecipeFormSheet: View {
    @ObservedObject var store: RecipesStore
    let assistant: AIImportAssistant
    let defaultAuthor: String
    let editing: FamilyRecipe?

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var category: RecipeCategory = .dinner
    @State private var ingredients: [String] = []
    @State private var newIngredient = ""
    @State private var instructions = ""
    @State private var story = ""
    @State private var prepTime = ""
    @State private var servingsText = ""

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var existingImageFilename: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    photoBlock
                }
                Section("Basics") {
                    TextField("Recipe name", text: $title)
                    TextField("From who? (e.g. Grandma Rose)", text: $author)
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases) { c in
                            Label(c.displayName, systemImage: c.systemImage).tag(c)
                        }
                    }
                    HStack {
                        TextField("Prep time (e.g. 45 mins)", text: $prepTime)
                        Divider().frame(height: 22)
                        TextField("Servings", text: $servingsText)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                }
                Section("Ingredients") {
                    HStack {
                        TextField("Add an ingredient", text: $newIngredient)
                        Button {
                            let t = newIngredient.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return }
                            ingredients.append(assistant.cleanIngredient(t))
                            newIngredient = ""
                        } label: { Image(systemName: "plus.circle.fill") }
                    }
                    ForEach(ingredients.indices, id: \.self) { i in
                        HStack {
                            Text(ingredients[i])
                            Spacer()
                            Button { ingredients.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Section("Instructions") {
                    TextField("Step by step…", text: $instructions, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section("The story behind it") {
                    TextField("What makes this recipe special?", text: $story, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(editing == nil ? "Add Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Save" : "Update", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { photoData = data }
                }
            }
        }
    }

    @ViewBuilder
    private var photoBlock: some View {
        VStack {
            if let data = photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let name = existingImageFilename, let img = LocalImage.load(filename: name) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color.orange.opacity(0.18), Color.pink.opacity(0.18)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 120)
                    .overlay(Image(systemName: "photo.fill").font(.title).foregroundColor(.orange))
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoData == nil && existingImageFilename == nil ? "Choose photo" : "Change photo",
                      systemImage: "photo.on.rectangle")
            }
        }
    }

    private func prefill() {
        if let r = editing {
            title = r.title
            author = r.author
            category = r.category
            ingredients = r.ingredients
            instructions = r.instructions
            story = r.story
            prepTime = r.prepTime
            servingsText = r.servings.map(String.init) ?? ""
            existingImageFilename = r.localImageFilename
        } else {
            author = defaultAuthor
        }
    }

    private func save() {
        var localName = existingImageFilename
        if let data = photoData {
            localName = LocalImage.save(data: data)
        }
        let recipe = FamilyRecipe(
            id: editing?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            author: author,
            category: category,
            imageURL: nil,
            localImageFilename: localName,
            ingredients: ingredients,
            instructions: instructions,
            story: story,
            prepTime: prepTime,
            servings: Int(servingsText),
            createdDate: editing?.createdDate ?? Date()
        )
        store.upsert(recipe)
        dismiss()
    }
}

// MARK: - Detail

private struct RecipeDetailSheet: View {
    let recipe: FamilyRecipe
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let local = recipe.localImageFilename, let img = LocalImage.load(filename: local) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 220).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.title).font(.title2.weight(.semibold))
                        if !recipe.author.isEmpty {
                            Label("From \(recipe.author)", systemImage: "heart.fill")
                                .font(.subheadline).foregroundColor(.pink)
                        }
                        HStack(spacing: 12) {
                            chip(recipe.category.displayName, color: recipe.category.color)
                            if !recipe.prepTime.isEmpty {
                                Label(recipe.prepTime, systemImage: "clock")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            if let s = recipe.servings {
                                Label("\(s) servings", systemImage: "person.2")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }

                    if !recipe.ingredients.isEmpty {
                        sectionHeader("Ingredients")
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(recipe.ingredients, id: \.self) { ing in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 7)
                                        .foregroundColor(.orange)
                                    Text(ing).font(.subheadline)
                                }
                            }
                        }
                    }

                    if !recipe.instructions.isEmpty {
                        sectionHeader("Instructions")
                        Text(recipe.instructions).font(.subheadline)
                    }

                    if !recipe.story.isEmpty {
                        sectionHeader("The story")
                        Text("\u{201C}\(recipe.story)\u{201D}").font(.subheadline.italic()).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { onEdit(); dismiss() } label: { Label("Edit", systemImage: "pencil") }
                        Button { onExport() } label: { Label("Export JSON", systemImage: "square.and.arrow.up") }
                        Divider()
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .alert("Delete this recipe?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { onDelete(); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s).font(.headline).padding(.top, 4)
    }
    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundColor(color)
    }
}

// MARK: - Paste & AI Organize

private struct PasteRecipeSheet: View {
    let assistant: AIImportAssistant
    let onParsed: (FamilyRecipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedText = ""
    @State private var preview: FamilyRecipe? = nil
    @State private var organizing = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste a recipe from anywhere — AI will sort it into ingredients, instructions, prep time, and a category.")
                    .font(.caption).foregroundColor(.secondary)
                TextEditor(text: $pastedText)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                Button {
                    Task {
                        organizing = true
                        preview = await assistant.organizeRecipe(from: pastedText)
                        organizing = false
                    }
                } label: {
                    if organizing { ProgressView() } else {
                        Label("Organize with AI", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(pastedText.trimmingCharacters(in: .whitespaces).isEmpty || organizing)

                if let p = preview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(p.title).font(.headline)
                            Text("Category: \(p.category.displayName)").font(.caption).foregroundColor(.secondary)
                            if !p.prepTime.isEmpty { Text("Prep: \(p.prepTime)").font(.caption) }
                            if let s = p.servings { Text("Servings: \(s)").font(.caption) }
                            if !p.ingredients.isEmpty {
                                Text("Ingredients").font(.subheadline.weight(.semibold))
                                ForEach(p.ingredients, id: \.self) { i in
                                    Text("• \(i)").font(.caption)
                                }
                            }
                            if !p.instructions.isEmpty {
                                Text("Instructions").font(.subheadline.weight(.semibold))
                                Text(p.instructions).font(.caption)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                    }
                    Button {
                        onParsed(p); dismiss()
                    } label: {
                        Label("Save recipe", systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Paste & Organize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Chip (shared)

private struct Chip: View {
    let title: String
    let systemImage: String
    let active: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(title).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule().fill(active ? color.opacity(0.18) : Color(.secondarySystemBackground))
            )
            .foregroundColor(active ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ShareSheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Local image helpers

enum LocalImage {
    /// Saves JPEG-compressed data to the Documents directory and returns the filename.
    static func save(data: Data) -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let name = "recipe_\(UUID().uuidString).jpg"
        let url = docs.appendingPathComponent(name)
        // If incoming data isn't JPEG, recompress.
        if let img = UIImage(data: data),
           let jpeg = img.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: url, options: .atomic)
        } else {
            try? data.write(to: url, options: .atomic)
        }
        return name
    }

    static func load(filename: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
