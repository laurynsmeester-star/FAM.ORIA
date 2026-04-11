//
//  HomePageView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// The main home page view shown after successful authentication
struct HomePageView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            // Home/Feed Tab
            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            // Calendar Tab
            CalendarTab()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            
            // Family Tab
            FamilyTab()
                .tabItem {
                    Label("Family", systemImage: "person.2.fill")
                }
            
            // Profile Tab
            ProfileTab()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

// MARK: - Home Tab

struct HomeTab: View {
    @EnvironmentObject var appState: AppState
    @State private var newPost = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with family name
                    FamilyHeaderView()
                    
                    // Quick Stats
                    QuickStatsView()
                        .padding()
                    
                    // Post composer
                    PostComposerView(newPost: $newPost, onPost: addPost)
                        .padding(.horizontal)
                    
                    // Feed
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.posts.sorted { $0.timestamp > $1.timestamp }) { post in
                                PostCard(post: post)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func addPost() {
        guard !newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let post = FamilyPost(
            id: UUID().uuidString,
            authorName: appState.currentUser?.name ?? "Unknown",
            content: newPost,
            timestamp: Date()
        )
        
        appState.posts.append(post)
        newPost = ""
    }
}

struct FamilyHeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentFamily?.name ?? "My Family")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Welcome, \(appState.currentUser?.name ?? "User")!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "house.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct QuickStatsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "person.2.fill",
                value: "\(appState.currentFamily?.members.count ?? 0)",
                label: "Members"
            )
            
            StatCard(
                icon: "calendar",
                value: "\(upcomingEventsCount)",
                label: "Events"
            )
            
            StatCard(
                icon: "bubble.left.fill",
                value: "\(appState.posts.count)",
                label: "Posts"
            )
        }
    }
    
    private var upcomingEventsCount: Int {
        appState.events.filter { $0.date >= Date() }.count
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct PostComposerView: View {
    @Binding var newPost: String
    let onPost: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Share something with your family...", text: $newPost, axis: .vertical)
                .lineLimit(1...3)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            
            Button(action: onPost) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .padding()
                    .background(newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct PostCard: View {
    let post: FamilyPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.headline)
                    
                    Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(post.content)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Calendar Tab

struct CalendarTab: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate = Date()
    @State private var showAddEvent = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color(.systemBackground))
                    
                    List {
                        if eventsForSelectedDay.isEmpty {
                            Text("No events for this day")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(eventsForSelectedDay) { event in
                                EventRow(event: event)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
            }
        }
    }
    
    private var eventsForSelectedDay: [FamilyEvent] {
        appState.events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }
}

struct EventRow: View {
    let event: FamilyEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                
                Text(event.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                
                Spacer()
                
                Text("by \(event.createdBy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Family Tab

struct FamilyTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showInvite = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.currentFamily?.name ?? "My Family")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("\(appState.currentFamily?.members.count ?? 0) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            showInvite = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
                
                Section("Members") {
                    if let members = appState.currentFamily?.members {
                        ForEach(members) { member in
                            MemberRow(member: member)
                        }
                    }
                }
                
                Section("Pending Invites") {
                    if appState.pendingInvites.isEmpty {
                        Text("No pending invites")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appState.pendingInvites) { invite in
                            InviteRow(invite: invite)
                        }
                    }
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showInvite) {
                InviteSheet()
            }
        }
    }
}

struct MemberRow: View {
    let member: User
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)
                
                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let role = member.role {
                Text(role.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(role == .admin ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundColor(role == .admin ? .purple : .blue)
                    .cornerRadius(8)
            }
        }
    }
}

struct InviteRow: View {
    @EnvironmentObject var appState: AppState
    let invite: Invite
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.familyName)
                    .font(.body)
                
                Text(invite.invitedEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Accept") {
                appState.accept(invite: invite)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct InviteSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Invite Family Member")
                } footer: {
                    Text("Enter the email address of the person you want to invite to your family.")
                }
            }
            .navigationTitle("Send Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        appState.createInvite(for: email)
                        dismiss()
                    }
                    .disabled(email.isEmpty || !email.contains("@"))
                }
            }
        }
    }
}

// MARK: - Profile Tab

struct ProfileTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.currentUser?.name ?? "User")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(appState.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let role = appState.currentUser?.role {
                                Text(role.rawValue.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(role == .admin ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(role == .admin ? .purple : .blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Account") {
                    NavigationLink {
                        Text("Settings")
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

#Preview {
    HomePageView()
        .environmentObject({
            let state = AppState()
            state.isAuthenticated = true
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "f1", role: .admin)
            state.currentFamily = Family(id: "f1", name: "The Doe Family", members: [
                User(id: "1", name: "John Doe", email: "john@example.com", familyId: "f1", role: .admin),
                User(id: "2", name: "Jane Doe", email: "jane@example.com", familyId: "f1", role: .member)
            ])
            state.posts = [
                FamilyPost(id: "1", authorName: "John Doe", content: "Welcome to our family page!", timestamp: Date()),
                FamilyPost(id: "2", authorName: "Jane Doe", content: "Looking forward to our trip this weekend!", timestamp: Date().addingTimeInterval(-3600))
            ]
            state.events = [
                FamilyEvent(id: "1", title: "Family Dinner", date: Date(), createdBy: "John Doe")
            ]
            return state
        }())
}
