import SwiftUI

// MARK: - EXAMPLE VIEWS
// These are example implementations for reference.
// The actual production views are in separate files.
// Some structs are prefixed with "Example" to avoid conflicts with production code.

// MARK: - Create Post View

struct CreatePostView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var content = ""
    @State private var isPosting = false
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if content.isEmpty {
                                Text("What's on your mind?")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 12)
                                    .padding(.top, 16)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                    )
                
                if let error = error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createPost()
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
        }
    }
    
    private func createPost() {
        isPosting = true
        error = nil
        
        Task {
            do {
                try await appState.createPost(content: content)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isPosting = false
                }
            }
        }
    }
}

// MARK: - Family Feed View

struct FamilyFeedListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreatePost = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.posts.isEmpty {
                    ContentUnavailableView {
                        Label("No Posts Yet", systemImage: "text.bubble")
                    } description: {
                        Text("Be the first to share something with your family!")
                    } actions: {
                        Button("Create Post") {
                            showCreatePost = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(appState.posts) { post in
                            PostRow(post: post)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if post.authorName == appState.currentUser?.name {
                                        Button(role: .destructive) {
                                            deletePost(post)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Family Feed")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreatePost = true
                    } label: {
                        Label("New Post", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
        }
    }
    
    private func deletePost(_ post: FamilyPost) {
        Task {
            do {
                try await appState.deletePost(post)
            } catch {
                print("Error deleting post: \(error)")
            }
        }
    }
}

struct PostRow: View {
    let post: FamilyPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(post.authorName.prefix(1))
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .fontWeight(.semibold)
                    
                    Text(post.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text(post.content)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Event View

struct CreateEventView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var date = Date()
    @State private var isCreating = false
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event Title", text: $title)
                    
                    DatePicker("Date & Time", selection: $date, in: Date()...)
                }
                
                if let error = error {
                    Section {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createEvent()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createEvent() {
        isCreating = true
        error = nil
        
        Task {
            do {
                try await appState.createEvent(title: title, date: date)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isCreating = false
                }
            }
        }
    }
}

// MARK: - Family Events List View

struct FamilyEventsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateEvent = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.events.isEmpty {
                    ContentUnavailableView {
                        Label("No Events Scheduled", systemImage: "calendar")
                    } description: {
                        Text("Create an event to help your family stay organized!")
                    } actions: {
                        Button("Create Event") {
                            showCreateEvent = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(appState.events) { event in
                            ExampleEventRow(event: event)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if event.createdBy == appState.currentUser?.id {
                                        Button(role: .destructive) {
                                            deleteEvent(event)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Family Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateEvent = true
                    } label: {
                        Label("New Event", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView()
            }
        }
    }
    
    private func deleteEvent(_ event: FamilyEvent) {
        Task {
            do {
                try await appState.deleteEvent(event)
            } catch {
                print("Error deleting event: \(error)")
            }
        }
    }
}

struct ExampleEventRow: View {
    let event: FamilyEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Date bubble
            VStack(spacing: 2) {
                Text(event.date, format: .dateTime.month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(event.date, format: .dateTime.day())
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                Text(event.date, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if isUpcoming(event.date) {
                    Text(timeUntilEvent(event.date))
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func isUpcoming(_ date: Date) -> Bool {
        date > Date() && date.timeIntervalSinceNow < 86400 * 7 // Within next 7 days
    }
    
    private func timeUntilEvent(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let days = Int(interval / 86400)
        
        if days == 0 {
            let hours = Int(interval / 3600)
            if hours == 0 {
                return "Starting soon"
            } else if hours == 1 {
                return "In 1 hour"
            } else {
                return "In \(hours) hours"
            }
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "In \(days) days"
        }
    }
}

// MARK: - Combined Tab View Example

struct FamilyContentTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            FamilyFeedListView()
                .tabItem {
                    Label("Feed", systemImage: "text.bubble.fill")
                }
            
            FamilyEventsListView()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
            
            InviteCodeView()
                .tabItem {
                    Label("Invite", systemImage: "person.badge.plus")
                }
        }
    }
}

// MARK: - Previews

#Preview("Create Post") {
    CreatePostView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "family1", role: .member)
            state.currentFamily = Family(id: "family1", name: "The Doe Family", members: [])
            return state
        }())
}

#Preview("Family Feed") {
    FamilyFeedListView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "family1", role: .member)
            state.currentFamily = Family(id: "family1", name: "The Doe Family", members: [])
            state.posts = [
                FamilyPost(id: "1", authorName: "John Doe", content: "Hello family! How is everyone doing?", timestamp: Date().addingTimeInterval(-3600)),
                FamilyPost(id: "2", authorName: "Jane Doe", content: "Great day at the park today! 🌳", timestamp: Date().addingTimeInterval(-7200))
            ]
            return state
        }())
}

#Preview("Create Event") {
    CreateEventView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "family1", role: .member)
            state.currentFamily = Family(id: "family1", name: "The Doe Family", members: [])
            return state
        }())
}

#Preview("Family Events") {
    FamilyEventsListView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "family1", role: .member)
            state.currentFamily = Family(id: "family1", name: "The Doe Family", members: [])
            state.events = [
                FamilyEvent(id: "1", title: "Family Dinner", date: Date().addingTimeInterval(86400), createdBy: "1"),
                FamilyEvent(id: "2", title: "Movie Night", date: Date().addingTimeInterval(259200), createdBy: "1"),
                FamilyEvent(id: "3", title: "Beach Trip", date: Date().addingTimeInterval(604800), createdBy: "2")
            ]
            return state
        }())
}
