import SwiftUI

struct LoadingScreen: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("First", value: Route.first)
                NavigationLink("Second", value: Route.second)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .first:
                    FirstView()
                case .second:
                    SecondView()
                case .detail(let id):
                    Text("Detail for id: \(id)")
                        .navigationTitle("Detail")
                }
            }
            .navigationTitle("Menu")
        }
    }
}

enum Route: Hashable {
    case first
    case second
    case detail(id: String)
}

struct FirstView: View {
    var body: some View {
        Text("welcome to the first screen")
            .navigationTitle("First")
    }
}

struct SecondView: View {
    var body: some View {
        Text("welcome to the second screen")
            .navigationTitle("Second")
    }
}

#Preview {
    LoadingScreen()
}
