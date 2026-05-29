//
//  FamoriaNavigationLayout.swift
//  Famoria 2026
//

import SwiftUI

// MARK: - Page Identifiers

enum FamoriaPage: String, CaseIterable, Identifiable {
    case home            = "Home"
    case chat            = "Chat"
    case familyUpdates   = "FamilyUpdates"
    case albums          = "Albums"
    case documents       = "Documents"
    case journal         = "Journal"
    case events          = "Events"
    case recipes         = "Recipes"
    case health          = "Health"
    case familyTree      = "FamilyTree"
    case profile         = "Profile"
    case familySettings  = "FamilySettings"
    case menu            = "Menu"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .home:           return ""
        case .chat:           return "Chat"
        case .familyUpdates:  return "Family Updates"
        case .albums:         return "Photo Albums"
        case .documents:      return "Documents"
        case .journal:        return "Journal"
        case .events:         return "Events"
        case .recipes:        return "Recipes"
        case .health:         return "Family Health"
        case .familyTree:     return "Family Tree"
        case .profile:        return "Profile"
        case .familySettings: return "Family Settings"
        case .menu:           return "More"
        }
    }
}

// MARK: - NavItem

struct NavItem: Identifiable {
    var id: String { page.rawValue }
    let name: String
    let systemImage: String
    let page: FamoriaPage

    static let all: [NavItem] = [
        NavItem(name: "Home",           systemImage: "house.fill",              page: .home),
        NavItem(name: "Messages",       systemImage: "message.fill",            page: .chat),
        NavItem(name: "Family Updates", systemImage: "newspaper.fill",          page: .familyUpdates),
        NavItem(name: "Photo Albums",   systemImage: "camera.fill",             page: .albums),
        NavItem(name: "Documents",      systemImage: "doc.text.fill",           page: .documents),
        NavItem(name: "Family Journal", systemImage: "book.fill",               page: .journal),
        NavItem(name: "Events",         systemImage: "calendar",                page: .events),
        NavItem(name: "Recipes",        systemImage: "fork.knife",              page: .recipes),
        NavItem(name: "Family Health",  systemImage: "heart.fill",              page: .health),
        NavItem(name: "Family Tree",    systemImage: "person.3.fill",           page: .familyTree),
        NavItem(name: "My Profile",     systemImage: "person.crop.circle.fill", page: .profile)
    ]
}

// MARK: - Theme Colors

private enum FamoriaTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.95, blue: 1.00),
            Color(red: 1.00, green: 0.95, blue: 0.97),
            Color(red: 0.96, green: 0.94, blue: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent        = Color(red: 0.49, green: 0.23, blue: 0.93)
    static let accentSoftBg  = Color(red: 0.95, green: 0.91, blue: 0.99)
    static let accentHoverBg = Color(red: 0.98, green: 0.96, blue: 1.00)
    static let slateText     = Color(red: 0.20, green: 0.25, blue: 0.33)
}

// MARK: - Sidebar (iPad / Mac)

struct FamoriaSidebar: View {
    @Binding var currentPage: FamoriaPage
    let familyName: String
    let currentUserName: String?
    let userIsAdmin: Bool
    @Binding var darkMode: Bool
    var onToggleDarkMode: () -> Void
    var onLogOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { currentPage = .home } label: {
                VStack(spacing: 4) {
                    Text(familyName)
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(FamoriaTheme.slateText)
                    Text("Memories & More")
                        .font(.caption).foregroundColor(.secondary).tracking(0.5)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(NavItem.all) { item in sidebarRow(item) }
                if userIsAdmin {
                    sidebarRow(NavItem(name: "Family Settings", systemImage: "person.3.fill", page: .familySettings))
                }
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: onToggleDarkMode) {
                    HStack {
                        Image(systemName: darkMode ? "sun.max.fill" : "moon.fill")
                        Text(darkMode ? "Light Mode" : "Dark Mode"); Spacer()
                    }.padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                }.buttonStyle(.plain).foregroundColor(FamoriaTheme.slateText)

                Button(action: onLogOut) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out"); Spacer()
                    }.padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                }.buttonStyle(.plain).foregroundColor(FamoriaTheme.slateText)

                VStack(spacing: 4) {
                    if let name = currentUserName {
                        Text("Welcome, \(name)!")
                            .font(.footnote).fontWeight(.medium).foregroundColor(FamoriaTheme.slateText)
                    }
                    Text("Made with 💕 for our family")
                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding().frame(maxWidth: .infinity).background(FamoriaTheme.accentSoftBg).cornerRadius(16)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 24)
        .frame(width: 288).background(.thinMaterial)
        .overlay(Rectangle().frame(width: 1).foregroundColor(FamoriaTheme.accentSoftBg), alignment: .trailing)
    }

    @ViewBuilder
    private func sidebarRow(_ item: NavItem) -> some View {
        let isActive = currentPage == item.page
        Button { currentPage = item.page } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage).frame(width: 20)
                    .foregroundColor(isActive ? FamoriaTheme.accent : .secondary)
                Text(item.name).font(.subheadline).fontWeight(.medium)
                    .foregroundColor(isActive ? FamoriaTheme.accent : FamoriaTheme.slateText)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isActive ? FamoriaTheme.accentSoftBg : Color.clear).cornerRadius(12)
        }.buttonStyle(.plain)
    }
}

// MARK: - Mobile Header

struct FamoriaMobileHeader: View {
    let currentPage: FamoriaPage
    let familyName: String
    let unreadCount: Int
    @Binding var menuOpen: Bool
    var onSearch: () -> Void
    var onBellTapped: () -> Void

    private var title: String {
        currentPage == .home ? familyName : currentPage.displayTitle
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { menuOpen.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.medium)).foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            Text(title).font(.headline).foregroundColor(.primary).lineLimit(1)
            Spacer()
            HStack(spacing: 2) {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass").font(.headline).foregroundColor(.primary).padding(8)
                }
                .accessibilityLabel("Search")

                Button(action: onBellTapped) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell").font(.headline).foregroundColor(.primary).padding(8)
                        if unreadCount > 0 {
                            Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                .font(.caption2).fontWeight(.semibold).foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18).padding(.horizontal, 4)
                                .background(Color.red).clipShape(Capsule()).offset(x: 4, y: -4)
                        }
                    }
                }
                .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications")
                .accessibilityHint("Open notifications")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.3)), alignment: .bottom)
    }
}

// MARK: - Mobile Footer Navigation (4 tabs)

struct FamoriaMobileFooterNav: View {
    @Binding var currentPage: FamoriaPage
    let unreadMessagesCount: Int

    private let bottomItems: [NavItem] = [
        NavItem(name: "Home",   systemImage: "house.fill",   page: .home),
        NavItem(name: "Events", systemImage: "calendar",     page: .events),
        NavItem(name: "Albums", systemImage: "camera.fill",  page: .albums),
        NavItem(name: "Chat",   systemImage: "message.fill", page: .chat),
    ]

    var body: some View {
        HStack {
            ForEach(bottomItems) { item in tabButton(item) }
        }
        .padding(.top, 6).padding(.bottom, 2)
        .background(Color(.systemBackground))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.3)), alignment: .top)
    }

    private func tabButton(_ item: NavItem) -> some View {
        let isActive = currentPage == item.page
        return Button {
            currentPage = item.page
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: item.systemImage).font(.system(size: 20))
                    if item.page == .chat && unreadMessagesCount > 0 {
                        Text(unreadMessagesCount > 99 ? "99+" : "\(unreadMessagesCount)")
                            .font(.caption2).fontWeight(.semibold).foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16).padding(.horizontal, 3)
                            .background(Color.red).clipShape(Capsule()).offset(x: 14, y: -10)
                    }
                }
                Text(item.name).font(.caption2).fontWeight(isActive ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundColor(isActive ? FamoriaTheme.accent : .secondary)
        }
    }
}

// MARK: - Slide-out Menu Drawer

struct FamoriaMenuDrawer: View {
    @Binding var currentPage: FamoriaPage
    @Binding var isOpen: Bool
    let userIsAdmin: Bool
    @Binding var darkMode: Bool
    var onToggleDarkMode: () -> Void
    var onLogOut: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { isOpen = false } }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Menu").font(.title2).fontWeight(.bold).foregroundColor(FamoriaTheme.slateText)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { isOpen = false }
                    } label: {
                        Image(systemName: "xmark").font(.headline).foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground)).clipShape(Circle())
                    }
                }.padding()
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(NavItem.all) { item in drawerRow(item) }
                        if userIsAdmin {
                            drawerRow(NavItem(name: "Family Settings", systemImage: "gearshape.fill", page: .familySettings))
                        }
                        Divider().padding(.vertical, 8)
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { isOpen = false }
                            onToggleDarkMode()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: darkMode ? "sun.max.fill" : "moon.fill").frame(width: 20)
                                Text(darkMode ? "Light Mode" : "Dark Mode").font(.subheadline).fontWeight(.medium)
                                Spacer()
                            }.padding(.horizontal, 14).padding(.vertical, 12).foregroundColor(FamoriaTheme.slateText)
                        }.buttonStyle(.plain)
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { isOpen = false }
                            onLogOut()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 20)
                                Text("Log Out").font(.subheadline).fontWeight(.medium)
                                Spacer()
                            }.padding(.horizontal, 14).padding(.vertical, 12).foregroundColor(.red)
                        }.buttonStyle(.plain)
                    }.padding(.horizontal, 8).padding(.vertical, 4)
                }
            }
            .frame(width: 280).background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.2), radius: 16, x: 4)
            .transition(.move(edge: .leading))
        }
    }

    private func drawerRow(_ item: NavItem) -> some View {
        let isActive = currentPage == item.page
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { isOpen = false }
            currentPage = item.page
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage).frame(width: 20)
                    .foregroundColor(isActive ? FamoriaTheme.accent : .secondary)
                Text(item.name).font(.subheadline).fontWeight(.medium)
                    .foregroundColor(isActive ? FamoriaTheme.accent : FamoriaTheme.slateText)
                Spacer()
                if isActive { Circle().fill(FamoriaTheme.accent).frame(width: 6, height: 6) }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isActive ? FamoriaTheme.accentSoftBg : Color.clear).cornerRadius(12)
        }.buttonStyle(.plain)
    }
}

// MARK: - Search Overlay

struct FamoriaSearchOverlay: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @Binding var currentPage: FamoriaPage
    var onSelectMember: (User) -> Void = { _ in }
    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    private var searchResults: [SearchResult] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        var results: [SearchResult] = []

        // Search pages
        for item in NavItem.all {
            if item.name.lowercased().contains(query) {
                results.append(SearchResult(id: "page-\(item.page.rawValue)", title: item.name,
                    subtitle: "Page", icon: item.systemImage, color: .purple, action: { currentPage = item.page; isPresented = false }))
            }
        }

        // Search family members
        for member in appState.currentFamily?.members ?? [] {
            if member.name.lowercased().contains(query) || member.email.lowercased().contains(query) {
                results.append(SearchResult(id: "member-\(member.id)", title: member.name,
                    subtitle: member.email, icon: "person.fill", color: .blue, action: {
                        isPresented = false
                        onSelectMember(member)
                    }))
            }
        }

        // Search events
        for event in appState.events {
            if event.title.lowercased().contains(query) || event.createdBy.lowercased().contains(query) {
                let eventDate = event.date
                results.append(SearchResult(id: "event-\(event.id)", title: event.title,
                    subtitle: "Event by \(event.createdBy)", icon: "calendar", color: .orange, action: {
                        appState.pendingEventDate = eventDate
                        currentPage = .events
                        isPresented = false
                    }))
            }
        }

        // Search posts
        for post in appState.posts {
            if post.content.lowercased().contains(query) || post.authorName.lowercased().contains(query) {
                results.append(SearchResult(id: "post-\(post.id)", title: post.authorName,
                    subtitle: String(post.content.prefix(60)), icon: "text.bubble.fill", color: .green, action: { currentPage = .home; isPresented = false }))
            }
        }

        // Search notifications
        for notif in appState.notifications {
            if notif.title.lowercased().contains(query) || notif.body.lowercased().contains(query) {
                results.append(SearchResult(id: "notif-\(notif.id)", title: notif.title,
                    subtitle: notif.body, icon: "bell.fill", color: .red, action: { isPresented = false }))
            }
        }

        return results
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search anything...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                    Button("Cancel") { isPresented = false }
                        .font(.subheadline).foregroundColor(.purple)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal)
                .padding(.top, 8)

                // Results
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle).foregroundColor(.secondary.opacity(0.5))
                        Text("Search pages, members, events, posts...")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle).foregroundColor(.secondary.opacity(0.5))
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(searchResults) { result in
                                Button(action: result.action) {
                                    HStack(spacing: 12) {
                                        Image(systemName: result.icon)
                                            .font(.callout).foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(result.color).cornerRadius(10)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title).font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                                            Text(result.subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                                    }
                                    .padding(10)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .onAppear { isFocused = true }
    }
}

private struct SearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
}

// MARK: - Layout Shell

struct FamoriaLayoutView<Content: View>: View {
    @EnvironmentObject var appState: AppState

    @Binding var currentPage: FamoriaPage
    @State private var menuOpen = false
    @State private var searchOpen = false
    @State private var showNotifications = false
    @State private var memberProfile: User?
    @AppStorage("famoria.darkMode") private var darkMode = false

    let content: () -> Content

    init(
        currentPage: Binding<FamoriaPage>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._currentPage = currentPage
        self.content = content
    }

    private var familyName: String {
        appState.currentFamily?.name ?? "Our Family"
    }
    private var isAdmin: Bool {
        appState.currentUser?.role == .admin || appState.currentUser?.role == .owner
    }
    private var isCompact: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }

    var body: some View {
        ZStack {
            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .preferredColorScheme(darkMode ? .dark : .light)
    }

    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var compactLayout: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                FamoriaMobileHeader(
                    currentPage: currentPage,
                    familyName: familyName,
                    unreadCount: appState.unreadNotificationCount,
                    menuOpen: $menuOpen,
                    onSearch: { searchOpen = true },
                    onBellTapped: { showNotifications = true }
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if currentPage != .profile {
                    FamoriaMobileFooterNav(
                        currentPage: $currentPage,
                        unreadMessagesCount: appState.unreadMessagesCount
                    )
                }
            }
            .background(FamoriaTheme.backgroundGradient.ignoresSafeArea())
        .overlay {
            if menuOpen {
                FamoriaMenuDrawer(
                    currentPage: $currentPage,
                    isOpen: $menuOpen,
                    userIsAdmin: isAdmin,
                    darkMode: $darkMode,
                    onToggleDarkMode: { darkMode.toggle() },
                    onLogOut: { Task { await appState.signOut() } }
                )
                .ignoresSafeArea()
            }
        }
        .overlay {
            if searchOpen {
                FamoriaSearchOverlay(
                    isPresented: $searchOpen,
                    currentPage: $currentPage,
                    onSelectMember: { memberProfile = $0 }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(item: $memberProfile) { member in
            FamilyMemberProfileSheet(member: member)
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 0) {
            FamoriaSidebar(
                currentPage: $currentPage,
                familyName: familyName,
                currentUserName: appState.currentUser?.name,
                userIsAdmin: isAdmin,
                darkMode: $darkMode,
                onToggleDarkMode: { darkMode.toggle() },
                onLogOut: { Task { await appState.signOut() } }
            )
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FamoriaTheme.backgroundGradient.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview("Famoria Layout") {
    struct Wrapper: View {
        @State private var page: FamoriaPage = .home
        var body: some View {
            FamoriaLayoutView(currentPage: $page) {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(0..<30) { i in
                            Text("Row \(i)").frame(maxWidth: .infinity).padding()
                                .background(Color(.systemBackground)).cornerRadius(12)
                        }
                    }.padding()
                }
            }
            .environmentObject({
                let s = AppState()
                s.isAuthenticated = true
                s.currentUser = User(id: "1", name: "Test", email: "t@t.com", familyId: "f1", role: .admin)
                s.currentFamily = Family(id: "f1", name: "Test Family", members: [])
                return s
            }())
        }
    }
    return Wrapper()
}
