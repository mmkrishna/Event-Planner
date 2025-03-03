import SwiftUI
import FirebaseAuth

struct GuestEvent {
    let title: String
    var guests: [Guest]
    
    var totalGuests: Int {
        guests.reduce(0) { $0 + $1.count }
    }
}

struct GuestsView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var guestName = ""
    @State private var guestCount = ""
    @State private var selectedEvent = ""
    @State private var showEventPicker = false
    @State private var isGuestCreated = false
    @State private var showingCreateGuestSheet = false
    
    private var currentUser: User {
        let auth = Auth.auth().currentUser
        let displayName = auth?.displayName ?? "User"
        let initials = displayName.components(separatedBy: " ")
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .prefix(2)
            .uppercased()
        return User(name: displayName, role: "User", avatar: String(initials))
    }
    
    private func createGuest() {
        guard !guestName.isEmpty,
              !guestCount.isEmpty,
              let count = Int(guestCount),
              !selectedEvent.isEmpty else { return }
        
        let newGuest = Guest(
            name: guestName,
            count: count,
            event: selectedEvent
        )
        
        // Save to Firebase
        eventStore.addGuest(newGuest, to: selectedEvent)
        
        // Reset form
        guestName = ""
        guestCount = ""
        selectedEvent = ""
        
        // Show success feedback
        isGuestCreated = true
    }
    
    var body: some View {
        NavigationView {
            BaseView(user: currentUser) {
                VStack(spacing: 20) {
                    // Guest List Overview
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Guest List Overview")
                                .font(.title2)
                                .foregroundColor(.purple)
                            Spacer()
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.pink)
                        }
                        
                        ForEach(eventStore.events) { event in
                            HStack {
                                Text(event.title)
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                Spacer()
                                Text("\(event.guestCount) Guests")
                                    .foregroundColor(.purple)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    
                    // Add Guest Button
                    Button(action: {
                        if !eventStore.events.isEmpty {
                            selectedEvent = eventStore.events[0].title
                            showingCreateGuestSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Add New Guest")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.pink, .purple], 
                                         startPoint: .leading, 
                                         endPoint: .trailing)
                        )
                        .cornerRadius(10)
                    }
                    .disabled(eventStore.events.isEmpty)
                    
                    // Guest Lists per Event
                    ForEach(eventStore.events) { event in
                        GuestEventCard(event: event)
                    }
                    
                    // Add some padding at the bottom for the tab bar
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateGuestSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Guest Details")) {
                            TextField("Guest Name", text: $guestName)
                            HStack {
                                Text("#")
                                    .foregroundColor(.gray)
                                TextField("Number of Guests", text: $guestCount)
                                    .keyboardType(.numberPad)
                            }
                            Picker("Event", selection: $selectedEvent) {
                                ForEach(eventStore.events) { event in
                                    Text(event.title).tag(event.title)
                                }
                            }
                        }
                    }
                    .navigationTitle("Add New Guest")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingCreateGuestSheet = false
                        }
                        .foregroundColor(.purple),
                        trailing: Button("Add") {
                            createGuest()
                            showingCreateGuestSheet = false
                        }
                        .disabled(guestName.isEmpty || guestCount.isEmpty || selectedEvent.isEmpty)
                        .foregroundColor((guestName.isEmpty || guestCount.isEmpty || selectedEvent.isEmpty) ? .gray : .pink)
                    )
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct GuestEventCard: View {
    let event: Event
    @EnvironmentObject var eventStore: EventStore
    @State private var editingGuest: Guest? = nil
    @State private var showingDeleteAlert = false
    @State private var guestToDelete: Guest? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Event Header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.pink)
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.purple)
                Spacer()
                Text("\(event.guestCount) Guests")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            // Guest Items
            ForEach(event.guests) { guest in
                HStack {
                    // Checkbox
                    Image(systemName: guest.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(guest.isSelected ? .green : .gray)
                    
                    // Guest Name
                    Text(guest.name)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    // Guest Count
                    Text("#\(guest.count)")
                        .foregroundColor(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(5)
                    
                    // Action buttons
                    HStack(spacing: 4) {
                        Button(action: {
                            editingGuest = guest
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.purple)
                                .font(.system(size: 24))
                        }
                        .frame(width: 32, height: 44)
                        
                        Button(action: {
                            guestToDelete = guest
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.pink)
                                .font(.system(size: 24))
                        }
                        .frame(width: 32, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .alert("Delete Guest", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let guest = guestToDelete,
                   let eventIndex = eventStore.events.firstIndex(where: { $0.title == event.title }) {
                    eventStore.events[eventIndex].guestCount -= guest.count
                    eventStore.events[eventIndex].guests.removeAll { $0.id == guest.id }
                }
            }
        } message: {
            Text("Are you sure you want to delete this guest? This action cannot be undone.")
        }
        .sheet(item: $editingGuest) { guest in
            EditGuestSheet(
                guest: guest,
                event: event.title
            )
        }
    }
}

struct EditGuestSheet: View {
    let guest: Guest
    let event: String
    @EnvironmentObject var eventStore: EventStore
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String
    @State private var editedCount: String
    
    init(guest: Guest, event: String) {
        self.guest = guest
        self.event = event
        _editedName = State(initialValue: guest.name)
        _editedCount = State(initialValue: String(guest.count))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Guest Details")) {
                    TextField("Guest Name", text: $editedName)
                    HStack {
                        Text("#")
                            .foregroundColor(.gray)
                        TextField("Number of Guests", text: $editedCount)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Edit Guest")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.purple),
                trailing: Button("Save") {
                    if let count = Int(editedCount),
                       let eventIndex = eventStore.events.firstIndex(where: { $0.title == event }),
                       let guestIndex = eventStore.events[eventIndex].guests.firstIndex(where: { $0.id == guest.id }) {
                        eventStore.events[eventIndex].guestCount = count
                        eventStore.events[eventIndex].guests[guestIndex].name = editedName
                        eventStore.events[eventIndex].guests[guestIndex].count = count
                        dismiss()
                    }
                }
                .disabled(editedName.isEmpty || editedCount.isEmpty)
                .foregroundColor((editedName.isEmpty || editedCount.isEmpty) ? .gray : .pink)
            )
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    GuestsView()
} 
