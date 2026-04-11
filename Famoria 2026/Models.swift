import Foundation
import SwiftUI

struct User: Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
    var familyId: String?
}

struct Family: Identifiable, Equatable {
    let id: String
    var name: String
    var members: [User]
}
