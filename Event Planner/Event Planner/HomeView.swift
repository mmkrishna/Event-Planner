import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var showingCreateEventSheet = false
    @State private var newEventTitle = ""
    @State private var newEventDate = Date()
    @State private var newEventTime = Date()
    @State private var newEventVenue = ""
    @State private var selectedGroups: Set<String> = []
    
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
    
    private var totalExpenses: Int {
        eventStore.expenseEvents.reduce(0) { total, event in
            total + event.expenses.count
        }
    }
    
    private var upcomingEvents: [Event] {
        eventStore.events.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationView {
            BaseView(user: currentUser) {
                ZStack {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Metrics Cards
                            HStack(spacing: 15) {
                                MetricCard(title: "Total Events", value: "\(eventStore.events.count)", subtitle: "Active Events", icon: "calendar.badge.plus")
                                MetricCard(title: "Total Budget", value: "₹\(eventStore.formatAmount(eventStore.totalBudget))", subtitle: "\(totalExpenses) Expenses", icon: "indianrupeesign")
                            }
                            
                            // Progress Section
                            ProgressSection(taskEvents: eventStore.taskEvents)
                            
                            Button(action: {
                                showingCreateEventSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Create New Event")
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
                            .padding(.top)
                            
                            // Upcoming Events - Use LazyVStack for better performance
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.pink)
                                    Text("Upcoming Events")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                }
                                
                                LazyVStack(spacing: 10) {
                                    ForEach(upcomingEvents) { event in
                                        EventCard(event: event)
                                    }
                                }
                            }
                            
                            // Guest List Overview
                            GuestOverviewSection(events: eventStore.events)
                            
                            // Add some padding at the bottom for the tab bar
                            Color.clear.frame(height: 60)
                        }
                        .padding()
                    }
                    .refreshable {
                        eventStore.refreshData()
                    }
                    
                    // Loading indicator
                    if eventStore.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(10)
                            .frame(width: 100, height: 100)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateEventSheet) {
                CreateEventSheet(
                    isPresented: $showingCreateEventSheet,
                    title: $newEventTitle,
                    date: $newEventDate,
                    time: $newEventTime,
                    venue: $newEventVenue,
                    selectedGroups: $selectedGroups,
                    onCreateEvent: createNewEvent
                )
            }
        }
    }
    
    private func createNewEvent() {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let newEvent = Event(
            title: newEventTitle,
            date: newEventDate,
            time: timeFormatter.string(from: newEventTime),
            venue: newEventVenue,
            completedTasks: 0,
            totalTasks: 0,
            guestCount: 0,
            guests: [],
            sharedGroups: Array(selectedGroups)
        )
        
        eventStore.addEvent(newEvent)
        
        // Reset form
        newEventTitle = ""
        newEventDate = Date()
        newEventTime = Date()
        newEventVenue = ""
        selectedGroups.removeAll()
        showingCreateEventSheet = false
    }
}

struct ProgressSection: View {
    let taskEvents: [TaskEvent]
    
    private var totalTasks: Int {
        taskEvents.reduce(0) { $0 + $1.totalTasks }
    }
    
    private var completedTasks: Int {
        taskEvents.reduce(0) { $0 + $1.completedTasks }
    }
    
    private var progress: Double {
        totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Overall Progress")
                    .font(.title2)
                    .foregroundColor(.purple)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.pink)
            }
            
            HStack {
                Text("Completed: \(completedTasks)")
                    .foregroundColor(.green)
                Spacer()
                Text("Pending: \(totalTasks - completedTasks)")
                    .foregroundColor(.orange)
            }
            
            ProgressBar(progress: progress)
            Text("\(completedTasks) of \(totalTasks) Tasks Completed")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
}

struct GuestOverviewSection: View {
    let events: [Event]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Guest List Overview")
                    .font(.title2)
                    .foregroundColor(.purple)
                Spacer()
                Image(systemName: "person.2.fill")
                    .foregroundColor(.pink)
            }
            
            ForEach(events) { event in
                HStack {
                    Text(event.title)
                        .foregroundColor(.purple)
                    Spacer()
                    Text("\(event.guestCount) Guests")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
}

struct CreateEventSheet: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var date: Date
    @Binding var time: Date
    @Binding var venue: String
    @Binding var selectedGroups: Set<String>
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    let onCreateEvent: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Event Name", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.pink)
                        TextField("Venue", text: $venue)
                    }
                }
                
                Section(header: Text("Share with Groups")) {
                    ForEach(profileViewModel.groups) { group in
                        Toggle(group.name, isOn: Binding(
                            get: { selectedGroups.contains(group.id.uuidString) },
                            set: { isSelected in
                                if isSelected {
                                    selectedGroups.insert(group.id.uuidString)
                                } else {
                                    selectedGroups.remove(group.id.uuidString)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Create New Event")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                    selectedGroups.removeAll()
                }
                .foregroundColor(.purple),
                trailing: Button(action: onCreateEvent) {
                    Text("Create")
                        .fontWeight(.bold)
                        .foregroundColor(title.isEmpty ? .gray : .pink)
                }
                .disabled(title.isEmpty)
            )
        }
        .presentationDetents([.medium])
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                Spacer()
                Image(systemName: icon)
                    .iconStyle(color: .pink)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.purple)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .cardStyle()
    }
}

struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .cornerRadius(5)
                
                Rectangle()
                    .foregroundColor(.purple)
                    .frame(width: geometry.size.width * progress)
                    .cornerRadius(5)
            }
        }
        .frame(height: 10)
    }
}

struct EventCard: View {
    let event: Event
    
    private var progressPercentage: Int {
        guard event.totalTasks > 0 else { return 0 }
        return Int((Double(event.completedTasks) / Double(event.totalTasks)) * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GradientIconBackground(systemName: "star.fill")
                
                Text(event.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
                
                Spacer()
                
                Text("\(event.completedTasks)/\(event.totalTasks) Tasks")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .cornerRadius(8)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .iconStyle(color: .purple.opacity(0.7), size: 15)
                Text(event.date.formatted(date: .long, time: .omitted))
                    .foregroundColor(.purple.opacity(0.8))
                Spacer()
                Image(systemName: "clock.fill")
                    .iconStyle(color: .pink.opacity(0.7), size: 15)
                Text(event.time)
                    .foregroundColor(.pink.opacity(0.8))
            }
            .font(.system(size: 15))
            
            if !event.venue.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .iconStyle(color: .pink.opacity(0.7), size: 15)
                    Text(event.venue)
                        .font(.system(size: 15))
                        .foregroundColor(.purple.opacity(0.8))
                }
            }
            
            VStack(spacing: 8) {
                ProgressBar(progress: event.totalTasks > 0 ? Double(event.completedTasks) / Double(event.totalTasks) : 0)
                    .frame(height: 8)
                
                Text("\(progressPercentage)% Complete")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .cardStyle()
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.currentIndex = hex.startIndex
        var rgbValue: UInt64 = 0
        
        if scanner.scanHexInt64(&rgbValue) {
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            
            self.init(red: r, green: g, blue: b)
        } else {
            self.init(.gray) // Default color in case of an invalid hex
        }
    }
}

#Preview {
    HomeView()
} 