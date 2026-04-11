//
//  MainAppView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/31/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            // Feed tab
            FamilyFeedView(appState: _appState)

                .tabItem {
                    Label("Feed", systemImage: "bubble.left.and.bubble.right")
                }
                .environmentObject(appState)

            // Calendar/Management tab
            NavigationStack {
                List {
                    Section(header: Text("Family")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(appState.currentFamily?.name ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(header: Text("Members")) {
                        if let members = appState.currentFamily?.members, !members.isEmpty {
                            ForEach(members) { m in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(m.name)
                                        Text(m.email).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(m.role?.rawValue.capitalized ?? "Member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button(role: .destructive) {
                                        appState.remove(member: m)
                                    } label: {
                                        Image(systemName: "person.fill.xmark")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            Text("No members yet")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(header: Text("Invite")) {
                        InviteComposer()
                    }

                    Section(header: Text("Pending Invites")) {
                        if appState.pendingInvites.isEmpty {
                            Text("No pending invites")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.pendingInvites) { invite in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(invite.invitedEmail)
                                        Text(invite.familyName).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Accept") { appState.accept(invite: invite) }
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(appState.currentFamily?.name ?? "Famoria")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign Out") { Task { await appState.signOut() } }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Test Invite Link") {
                            appState.handleIncomingInviteLink(id: UUID().uuidString)
                        }
                    }
                }
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
        }
    }
}

#Preview {
    MainAppView()
        .environmentObject(AppState())
}

