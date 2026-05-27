//
//  AlbumsView.swift
//  Famoria Update 2026
//
//  Root Photo Albums screen — grid of album cards with category filter tabs.
//  Present this via FamoriaAlbumsEntryViewController (UIKit bridge).
//

import SwiftUI

// MARK: - AlbumsView

struct AlbumsView: View {

    @StateObject private var store = AlbumStoreManager()
    @State private var showCreateForm  = false
    @State private var selectedFilter: AlbumCategory? = nil
    @State private var selectedAlbum:  FamoriaAlbum?  = nil

    private var filteredAlbums: [FamoriaAlbum] {
        guard let filter = selectedFilter else { return store.albums }
        return store.albums.filter { $0.category == filter }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                filterTabsView
                contentView
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear  { store.startListeningToAlbums() }
        .onDisappear { store.stopListeningToAlbums() }
        .sheet(isPresented: $showCreateForm) {
            AlbumFormView(store: store, existingAlbum: nil)
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album, store: store)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Family Photo Albums")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(Color(UIColor.label))
                Text("Trips, holidays, events & everyday moments")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { showCreateForm = true } label: {
                Label("New Album", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LinearGradient.famoriaPrimary)
                    .cornerRadius(12)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Filter Tabs

    private var filterTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: selectedFilter == nil) {
                    withAnimation(.spring(response: 0.3)) { selectedFilter = nil }
                }
                ForEach(AlbumCategory.allCases, id: \.self) { cat in
                    CategoryChip(
                        title: cat.displayName,
                        isSelected: selectedFilter == cat
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = (selectedFilter == cat) ? nil : cat
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if store.isLoading {
            skeletonGrid
        } else if filteredAlbums.isEmpty {
            emptyStateView
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(filteredAlbums) { album in
                    AlbumCardView(album: album)
                        .onTapGesture { selectedAlbum = album }
                }
            }
        }
    }

    // MARK: - Skeleton / Loading

    private var skeletonGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemFill))
                    .aspectRatio(0.9, contentMode: .fit)
                    .redacted(reason: .placeholder)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.92, blue: 0.94),
                                Color(red: 0.95, green: 0.91, blue: 0.99)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(LinearGradient.famoriaPrimary)
            }

            VStack(spacing: 6) {
                Text("No albums yet")
                    .font(.title3.weight(.semibold))
                Text("Start preserving your family memories\nby creating your first album")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button { showCreateForm = true } label: {
                Label("Create First Album", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(LinearGradient.famoriaPrimary)
                    .cornerRadius(14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .padding(.horizontal, 24)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}

// MARK: - AlbumCardView

struct AlbumCardView: View {
    let album: FamoriaAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            ZStack(alignment: .topLeading) {
                Group {
                    if let url = album.coverImageURL.flatMap(URL.init) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                placeholderCover
                            default:
                                Color(UIColor.systemFill)
                            }
                        }
                    } else {
                        placeholderCover
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()

                // Category badge
                Text("\(album.category.emoji) \(album.category.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(album.category.badgeForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(album.category.badgeBackground.opacity(0.92))
                    .cornerRadius(8)
                    .padding(10)
            }
            .roundedCorners(14, corners: [.topLeft, .topRight])

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(UIColor.label))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let date = album.date {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(date, style: .date)
                            .font(.caption)
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.caption2)
                        Text("\(album.photoCount) photo\(album.photoCount == 1 ? "" : "s")")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .roundedCorners(14, corners: [.bottomLeft, .bottomRight])
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var placeholderCover: some View {
        LinearGradient(
            colors: [Color(red: 0.99, green: 0.92, blue: 0.94), Color(red: 0.95, green: 0.91, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "camera.fill")
                .font(.system(size: 34))
                .foregroundColor(.famoriaRose.opacity(0.55))
        )
    }
}

// MARK: - CategoryChip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Color(UIColor.label))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyView(LinearGradient.famoriaPrimary)
                        : AnyView(Color(UIColor.secondarySystemGroupedBackground))
                )
                .cornerRadius(20)
                .shadow(color: isSelected ? Color.famoriaRose.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Corner Radius Helper

extension View {
    fileprivate func roundedCorners(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(AlbumsViewRoundedCorner(radius: radius, corners: corners))
    }
}

fileprivate struct AlbumsViewRoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#Preview {
    AlbumsView()
}

