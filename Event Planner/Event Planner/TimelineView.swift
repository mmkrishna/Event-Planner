import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct TimelineView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var showingEditSheet = false
    @State private var selectedEvent: Event?
    @State private var editEventTitle = ""
    @State private var editEventDate = Date()
    @State private var editEventTime = Date()
    @State private var showingDeleteAlert = false
    @State private var showingSuccessMessage = false
    
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
    
    var body: some View {
        NavigationView {
            BaseView(user: currentUser) {
                VStack(spacing: 20) {
                    // Section Title
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                            .font(.title2)
                        Text("Timeline")
                            .font(.title2.bold())
                            .foregroundColor(.purple)
                        Spacer()
                    }
                    .padding(.bottom, 5)
                    
                    if eventStore.events.isEmpty {
                        VStack(spacing: 15) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                            Text("No Events Yet")
                                .font(.headline)
                            Text("Create your first event from the Home tab")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    } else {
                        // Event Cards
                        ForEach(eventStore.events.sorted { $0.date < $1.date }) { event in
                            TimelineEventCard(event: event, onEdit: {
                                selectedEvent = event
                                editEventTitle = event.title
                                editEventDate = event.date
                                let timeFormatter = DateFormatter()
                                timeFormatter.dateFormat = "h:mm a"
                                if let time = timeFormatter.date(from: event.time) {
                                    editEventTime = time
                                }
                                showingEditSheet = true
                            }, onDelete: {
                                selectedEvent = event
                                showingDeleteAlert = true
                            })
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // Add some padding at the bottom for the tab bar
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: eventStore.events)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEditSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Event Details")) {
                            TextField("Event Name", text: $editEventTitle)
                                .textInputAutocapitalization(.words)
                            DatePicker("Date", selection: $editEventDate, displayedComponents: .date)
                                .tint(.purple)
                            DatePicker("Time", selection: $editEventTime, displayedComponents: .hourAndMinute)
                                .tint(.purple)
                        }
                    }
                    .navigationTitle("Edit Event")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingEditSheet = false
                        }
                        .foregroundColor(.purple),
                        trailing: Button(action: {
                            if let event = selectedEvent {
                                let timeFormatter = DateFormatter()
                                timeFormatter.timeStyle = .short
                                
                                let updatedEvent = Event(
                                    id: event.id,
                                    title: editEventTitle,
                                    date: editEventDate,
                                    time: timeFormatter.string(from: editEventTime),
                                    venue: event.venue,
                                    completedTasks: event.completedTasks,
                                    totalTasks: event.totalTasks,
                                    guestCount: event.guestCount,
                                    guests: event.guests
                                )
                                
                                eventStore.updateEvent(updatedEvent)
                                showingSuccessMessage = true
                                showingEditSheet = false
                            }
                        }) {
                            Text("Save")
                                .bold()
                        }
                        .disabled(editEventTitle.isEmpty)
                        .foregroundColor(editEventTitle.isEmpty ? .gray : .pink)
                    )
                }
                .presentationDetents([.medium])
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    withAnimation {
                        if let event = selectedEvent {
                            eventStore.deleteEvent(id: event.id)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this event? This action cannot be undone.")
            }
            .overlay {
                if showingSuccessMessage {
                    VStack {
                        Text("Event Updated")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .transition(.move(edge: .top))
                    .animation(.spring(), value: showingSuccessMessage)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSuccessMessage = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// Event Icon View
struct EventIconView: View {
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.pink.opacity(0.8), .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "star.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .semibold))
            }
    }
}

// Event Header View
struct EventHeaderView: View {
    let title: String
    let completedTasks: Int
    let totalTasks: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Event icon and title
            HStack(spacing: 12) {
                EventIconView()
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 4) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                }
                .frame(width: 32, height: 44)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.purple)
                        .font(.system(size: 24))
                }
                .frame(width: 32, height: 44)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.pink)
                        .font(.system(size: 24))
                }
                .frame(width: 32, height: 44)
            }
        }
    }
}

// Date Time Section
struct DateTimeSection: View {
    let date: Date
    let time: String
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .iconStyle(color: .purple.opacity(0.7), size: 15)
                Text(date.formatted(date: .long, time: .omitted))
                    .foregroundColor(.purple.opacity(0.8))
            }
            .font(.system(size: 15))
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .iconStyle(color: .pink.opacity(0.7), size: 15)
                Text(time)
                    .foregroundColor(.pink.opacity(0.8))
            }
            .font(.system(size: 15))
        }
    }
}

// Progress Stats Section
struct ProgressStatsSection: View {
    let completedTasks: Int
    let totalTasks: Int
    let guestCount: Int
    
    private var progressPercentage: Int {
        guard totalTasks > 0 else { return 0 }
        return Int((Double(completedTasks) / Double(totalTasks)) * 100)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundColor(.purple)
                    Text("\(completedTasks)/\(totalTasks)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.purple)
                    Text("Tasks")
                        .font(.system(size: 15))
                        .foregroundColor(.purple.opacity(0.7))
                }
                .badgeStyle(color: .purple)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.pink)
                    Text("\(guestCount)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.pink)
                    Text("Guests")
                        .font(.system(size: 15))
                        .foregroundColor(.pink.opacity(0.7))
                }
                .badgeStyle(color: .pink)
            }
            
            VStack(spacing: 6) {
                ProgressBar(progress: totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0)
                    .frame(height: 8)
                
                Text("\(progressPercentage)% Complete")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct TimelineEventCard: View {
    let event: Event
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingShareSheet = false
    @State private var shareEmail = ""
    @State private var selectedPermissions = Set<String>(["view"])
    @EnvironmentObject var eventStore: EventStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EventHeaderView(
                title: event.title,
                completedTasks: event.completedTasks,
                totalTasks: event.totalTasks,
                onEdit: onEdit,
                onDelete: onDelete,
                onShare: { showingShareSheet = true }
            )
            
            DateTimeSection(date: event.date, time: event.time)
            
            Divider()
                .background(Color.purple.opacity(0.1))
            
            ProgressStatsSection(
                completedTasks: event.completedTasks,
                totalTasks: event.totalTasks,
                guestCount: event.guestCount
            )
            
            // Shared Users Section
            if !event.sharedWith.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared with")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    ForEach(event.sharedWith, id: \.self) { userId in
                        SharedUserRow(userId: userId, canUnshare: event.createdByUID == Auth.auth().currentUser?.uid) {
                            eventStore.unshareEvent(event, withUser: userId)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .purple.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingShareSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Share with")) {
                        TextField("Email", text: $shareEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    Section(header: Text("Permissions")) {
                        Toggle("View", isOn: Binding(
                            get: { selectedPermissions.contains("view") },
                            set: { if $0 { selectedPermissions.insert("view") } else { selectedPermissions.remove("view") } }
                        ))
                        Toggle("Edit", isOn: Binding(
                            get: { selectedPermissions.contains("edit") },
                            set: { if $0 { selectedPermissions.insert("edit") } else { selectedPermissions.remove("edit") } }
                        ))
                    }
                }
                .navigationTitle("Share Event")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingShareSheet = false
                    },
                    trailing: Button("Share") {
                        eventStore.shareEvent(event, withEmail: shareEmail, permissions: Array(selectedPermissions))
                        showingShareSheet = false
                    }
                    .disabled(shareEmail.isEmpty || selectedPermissions.isEmpty)
                )
            }
            .presentationDetents([.medium])
        }
    }
}

struct SharedUserRow: View {
    let userId: String
    let canUnshare: Bool
    let onUnshare: () -> Void
    @State private var userName: String = ""
    
    var body: some View {
        HStack {
            if userName.isEmpty {
                Text(userId)
                    .font(.system(size: 14))
                    .onAppear {
                        // Fetch user name from Firestore
                        let db = Firestore.firestore()
                        db.collection("users").document(userId).getDocument { snapshot, error in
                            if let error = error {
                                print("Error fetching user: \(error.localizedDescription)")
                                return
                            }
                            
                            if let data = snapshot?.data(),
                               let name = data["name"] as? String {
                                userName = name
                            }
                        }
                    }
            } else {
                Text(userName)
                    .font(.system(size: 14))
            }
            
            Spacer()
            
            if canUnshare {
                Button(action: onUnshare) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview {
    TimelineView()
} 
