import Foundation
import FirebaseAuth

// Disambiguate between Firebase's User class and our app's User struct
// This file prevents redeclaration errors by defining these aliases once
typealias AppUser = User
typealias FirebaseUser = FirebaseAuth.User
