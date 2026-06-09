//
//  ContactsService.swift
//  Famoria 2026
//
//  Read-only `CNContactStore` wrapper used by the invite composer so
//  the user can pick a family member from their iPhone contacts
//  instead of typing the email by hand.
//
//  NSContactsUsageDescription is already in the Info.plist.
//

import Foundation
import os
import Combine
import Contacts

/// Minimal struct the invite UI binds to.
struct FamoriaContact: Identifiable, Hashable {
    var id: String { contactId }
    let contactId: String
    let name: String
    let email: String?
    let phone: String?
    let initials: String
}

@MainActor
final class ContactsService: ObservableObject {

    @Published private(set) var contacts: [FamoriaContact] = []
    @Published private(set) var didDenyAccess = false

    private let store = CNContactStore()

    /// Asks the user once and caches the result. Returns true if we now
    /// have access (or already did). False if the user denied.
    @discardableResult
    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .denied, .restricted:
            didDenyAccess = true
            return false
        case .notDetermined:
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                store.requestAccess(for: .contacts) { ok, _ in
                    Task { @MainActor in
                        self.didDenyAccess = !ok
                        cont.resume(returning: ok)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    /// Loads the user's contact list once, sorted alphabetically.
    /// Discards contacts with neither email nor phone.
    func loadContacts() async {
        guard await requestAccess() else { return }
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ].map { $0 as CNKeyDescriptor }

        let request = CNContactFetchRequest(keysToFetch: keys)
        var results: [FamoriaContact] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let fullName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let email = contact.emailAddresses.first.map { String($0.value) }
                let phone = contact.phoneNumbers.first.map { $0.value.stringValue }
                guard email != nil || phone != nil else { return }
                guard !fullName.isEmpty else { return }
                let initials = Self.initials(for: fullName)
                results.append(FamoriaContact(
                    contactId: contact.identifier,
                    name: fullName,
                    email: email,
                    phone: phone,
                    initials: initials
                ))
            }
        } catch {
            Log.appState.error("contacts enumerate failed: \(error.localizedDescription, privacy: .public)")
        }
        contacts = results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private static func initials(for name: String) -> String {
        let parts = name.split(separator: " ", omittingEmptySubsequences: true)
        let letters = parts.compactMap { $0.first.map(String.init) }.prefix(2)
        return letters.joined().uppercased()
    }
}
