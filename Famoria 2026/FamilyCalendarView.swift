import SwiftUI

struct FamilyCalendarView: View {
    
    @EnvironmentObject var appState: AppState
    @State private var selectedDate = Date()
    @State private var showAddEvent = false
    
    var body: some View {
        VStack {
            
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            
            List {
                ForEach(eventsForSelectedDay) { event in
                    VStack(alignment: .leading) {
                        Text(event.title)
                            .font(.headline)
                        Text(event.date.formatted())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Button("Add Event") {
                showAddEvent = true
            }
            .padding()
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView()
        }
    }
    
    var eventsForSelectedDay: [FamilyEvent] {
        appState.events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }
}