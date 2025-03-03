import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class EventStore: ObservableObject {
    @Published var events: [Event] = []
    @Published var taskEvents: [TaskEvent] = []
    @Published var expenseEvents: [ExpenseEvent] = []
    @Published var isLoading: Bool = false
    
    private var db = Firestore.firestore()
    private var listenerRegistrations: [ListenerRegistration] = []
    private let queue = DispatchQueue(label: "com.eventplanner.store", qos: .userInitiated)
    
    // Cache for expensive calculations
    private var cachedTotalBudget: Double?
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute
    
    static let shared = EventStore()
    
    private init() {
        setupFirestoreListeners()
    }
    
    // Computed property with caching for total budget
    var totalBudget: Double {
        // Check if we have a valid cached value
        if let cachedValue = cachedTotalBudget, 
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            return cachedValue
        }
        
        // Calculate the value
        let total = taskEvents.reduce(0) { total, event in
            total + event.totalBudget
        }
        
        // Cache the result
        cachedTotalBudget = total
        lastCacheUpdate = Date()
        
        return total
    }
    
    // Reset cache when data changes
    private func invalidateCache() {
        cachedTotalBudget = nil
        lastCacheUpdate = nil
    }
    
    private func setupFirestoreListeners() {
        // Remove any existing listeners
        queue.sync {
            listenerRegistrations.forEach { $0.remove() }
            listenerRegistrations.removeAll()
        }
        
        guard let userId = Auth.auth().currentUser?.uid else { 
            isLoading = false
            return 
        }
        print("Setting up listeners for user: \(userId)")
        
        // Get user group IDs once to avoid repeated calls
        let userGroupIds = getUserGroupIds()
        
        // Use a single filter for all queries to improve efficiency
        var filters: [Filter] = [
            Filter.whereField("createdByUID", isEqualTo: userId),
            Filter.whereField("sharedWith", arrayContains: userId)
        ]
        
        // Only add the sharedGroups filter if there are actually groups to check
        if !userGroupIds.isEmpty {
            filters.append(Filter.whereField("sharedGroups", arrayContainsAny: userGroupIds))
        }
        
        let accessFilter = Filter.orFilter(filters)
        
        // Track completion of all three listeners
        var completedListeners = 0
        let totalListeners = 3
        
        let checkAllCompleted = { [weak self] in
            completedListeners += 1
            if completedListeners >= totalListeners {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }
        
        // Listen for all events (owned + shared) in a single collection
        let eventsListener = db.collection("events")
            .whereFilter(accessFilter)
            .limit(to: 50) // Add pagination
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching events: \(error?.localizedDescription ?? "Unknown error")")
                    checkAllCompleted()
                    return
                }
                
                self.queue.async {
                    let events = documents.compactMap { document -> Event? in
                        try? document.data(as: Event.self)
                    }
                    print("Fetched \(events.count) total events")
                    
                    DispatchQueue.main.async {
                        self.events = events
                        self.objectWillChange.send()
                        checkAllCompleted()
                    }
                }
            }
            
        // Listen for task events from shared collection
        let taskEventsListener = db.collection("taskEvents")
            .whereFilter(accessFilter)
            .limit(to: 50) // Add pagination
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching task events: \(error?.localizedDescription ?? "Unknown error")")
                    checkAllCompleted()
                    return
                }
                
                self.queue.async {
                    let tasks = documents.compactMap { document -> TaskEvent? in
                        try? document.data(as: TaskEvent.self)
                    }
                    
                    DispatchQueue.main.async {
                        self.taskEvents = tasks
                        self.objectWillChange.send()
                        self.invalidateCache() // Invalidate cache when data changes
                        checkAllCompleted()
                    }
                }
            }
        
        // Listen for expense events from shared collection
        let expenseEventsListener = db.collection("expenseEvents")
            .whereFilter(accessFilter)
            .limit(to: 50) // Add pagination
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching expense events: \(error?.localizedDescription ?? "Unknown error")")
                    checkAllCompleted()
                    return
                }
                
                self.queue.async {
                    let expenses = documents.compactMap { document -> ExpenseEvent? in
                        try? document.data(as: ExpenseEvent.self)
                    }
                    
                    DispatchQueue.main.async {
                        self.expenseEvents = expenses
                        self.objectWillChange.send()
                        self.invalidateCache() // Invalidate cache when data changes
                        checkAllCompleted()
                    }
                }
            }
        
        queue.async {
            self.listenerRegistrations.append(contentsOf: [
                eventsListener,
                taskEventsListener,
                expenseEventsListener
            ])
        }
    }
    
    private func getUserGroupIds() -> [String] {
        // Get all group IDs that the user is a member of
        let groups = ProfileViewModel.shared.groups
        return groups.map { $0.id.uuidString }
    }
    
    func addEvent(_ event: Event) {
        guard let userId = Auth.auth().currentUser?.uid,
              let displayName = Auth.auth().currentUser?.displayName else { return }
        
        var newEvent = event
        newEvent.createdBy = displayName
        newEvent.createdByUID = userId
        
        // Create a batch write
        let batch = db.batch()
        
        do {
            // 1. Add event to shared events collection
            let eventRef = db.collection("events").document(event.id.uuidString)
            try batch.setData(from: newEvent, forDocument: eventRef)
            
            // 2. Create task event in shared collection
            let taskEvent = TaskEvent(
                title: event.title,
                tasks: [],
                sharedWith: event.sharedWith,
                sharedGroups: event.sharedGroups,
                createdByUID: userId
            )
            let taskEventRef = db.collection("taskEvents").document(event.title)
            try batch.setData(from: taskEvent, forDocument: taskEventRef)
            
            // 3. Create expense event in shared collection
            let expenseEvent = ExpenseEvent(
                title: event.title,
                totalAmount: 0,
                expenses: [],
                sharedWith: event.sharedWith,
                sharedGroups: event.sharedGroups,
                createdByUID: userId
            )
            let expenseEventRef = db.collection("expenseEvents").document(event.title)
            try batch.setData(from: expenseEvent, forDocument: expenseEventRef)
            
            // 4. Share with group members
            for groupId in event.sharedGroups {
                // Get group document
                db.collection("groups").document(groupId).getDocument { [weak self] snapshot, error in
                    guard let group = try? snapshot?.data(as: Group.self) else { return }
                    
                    // Update event with all member UIDs
                    var updatedEvent = newEvent
                    for member in group.members where member.uid != userId {
                        if !updatedEvent.sharedWith.contains(member.uid) {
                            updatedEvent.sharedWith.append(member.uid)
                        }
                    }
                    
                    // Update the event with all shared users
                    try? self?.db.collection("events")
                        .document(event.id.uuidString)
                        .setData(from: updatedEvent)
                }
            }
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("Error creating event: \(error)")
                }
            }
            
        } catch {
            print("Error creating event: \(error)")
        }
    }
    
    func shareEvent(_ event: Event, withEmail email: String, permissions: [String]) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("Attempting to share event: \(event.title) with email: \(email)")
        
        // First find the user by email
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error finding user: \(error.localizedDescription)")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("No user found with email: \(email)")
                    return
                }
                
                let targetUserId = document.documentID
                print("Found user with ID: \(targetUserId)")
                
                var updatedEvent = event
                if !updatedEvent.sharedWith.contains(targetUserId) {
                    updatedEvent.sharedWith.append(targetUserId)
                    
                    // Create a batch write
                    let batch = self?.db.batch()
                    
                    // Update the event in the current user's collection
                    if let batch = batch {
                        do {
                            // 1. Update in owner's collection
                            let ownerEventRef = self?.db.collection("events").document(event.id.uuidString)
                            
                            try batch.setData(from: updatedEvent, forDocument: ownerEventRef!)
                            
                            // 2. Create task event for shared user
                            let sharedTaskEvent = TaskEvent(
                                title: event.title,
                                tasks: [],
                                sharedWith: updatedEvent.sharedWith,
                                sharedGroups: updatedEvent.sharedGroups,
                                createdByUID: currentUserId
                            )
                            let taskEventRef = self?.db.collection("taskEvents").document(event.title)
                            
                            try batch.setData(from: sharedTaskEvent, forDocument: taskEventRef!)
                            
                            // 3. Create expense event for shared user
                            let sharedExpenseEvent = ExpenseEvent(
                                title: event.title,
                                totalAmount: 0,
                                expenses: [],
                                sharedWith: updatedEvent.sharedWith,
                                sharedGroups: updatedEvent.sharedGroups,
                                createdByUID: currentUserId
                            )
                            let expenseEventRef = self?.db.collection("expenseEvents").document(event.title)
                            
                            try batch.setData(from: sharedExpenseEvent, forDocument: expenseEventRef!)
                            
                            // Commit the batch
                            batch.commit { error in
                                if let error = error {
                                    print("Error committing share batch: \(error.localizedDescription)")
                                } else {
                                    print("Successfully shared event with user: \(targetUserId)")
                                }
                            }
                        } catch {
                            print("Error preparing share batch: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("Event already shared with user: \(targetUserId)")
                }
            }
    }
    
    func unshareEvent(_ event: Event, withUser userId: String) {
        var updatedEvent = event
        updatedEvent.sharedWith.removeAll { $0 == userId }
        updateEvent(updatedEvent)
    }
    
    func deleteEvent(id: UUID) {
        guard Auth.auth().currentUser != nil,
              let event = events.first(where: { $0.id == id }) else { return }
        
        // Delete event and its related collections
        let batch = db.batch()
        
        let eventRef = db.collection("events").document(id.uuidString)
        
        let taskEventRef = db.collection("taskEvents").document(event.title)
        
        let expenseEventRef = db.collection("expenseEvents").document(event.title)
        
        batch.deleteDocument(eventRef)
        batch.deleteDocument(taskEventRef)
        batch.deleteDocument(expenseEventRef)
        
        batch.commit { error in
            if let error = error {
                print("Error deleting event: \(error)")
            }
        }
    }
    
    func updateEvent(_ event: Event) {
        guard Auth.auth().currentUser != nil else { return }
        
        do {
            try db.collection("events").document(event.id.uuidString).setData(from: event)
        } catch {
            print("Error updating event: \(error)")
        }
    }
    
    func updateEventStats() {
        for (index, event) in events.enumerated() {
            if let taskEvent = taskEvents.first(where: { $0.title == event.title }) {
                events[index].totalTasks = taskEvent.totalTasks
                events[index].completedTasks = taskEvent.completedTasks
            }
        }
        objectWillChange.send()
    }
    
    func deleteExpense(_ expense: Expense, from eventTitle: String) {
        guard Auth.auth().currentUser != nil else { return }
        
        if let eventIndex = expenseEvents.firstIndex(where: { $0.title == eventTitle }) {
            var updatedExpenseEvent = expenseEvents[eventIndex]
            updatedExpenseEvent.removeExpense(expense)
            
            do {
                try db.collection("expenseEvents").document(eventTitle).setData(from: updatedExpenseEvent)
            } catch {
                print("Error deleting expense: \(error)")
            }
        }
    }
    
    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
    
    private func syncTaskWithExpense(_ task: Task) {
        guard Auth.auth().currentUser != nil else { return }
        
        if let expenseIndex = expenseEvents.firstIndex(where: { $0.title == task.event }) {
            // Create or update corresponding expense
            let expense = Expense(
                name: task.name,
                amount: Double(task.amount.replacingOccurrences(of: ",", with: "")) ?? 0,
                supplier: task.supplier,
                contact: task.contact,
                event: task.event,
                createdBy: task.createdBy,
                createdByUID: task.createdByUID,
                lastModifiedBy: task.lastModifiedBy,
                lastModifiedByUID: task.lastModifiedByUID,
                lastModifiedDate: task.lastModifiedDate
            )
            
            var updatedExpenseEvent = expenseEvents[expenseIndex]
            
            // Check if this task already has a corresponding expense
            if updatedExpenseEvent.expenses.contains(where: { $0.name == task.name }) {
                updatedExpenseEvent.updateExpense(expense)
            } else {
                updatedExpenseEvent.addExpense(expense)
            }
            
            // Save to Firestore
            do {
                try db.collection("expenseEvents").document(task.event).setData(from: updatedExpenseEvent)
            } catch {
                print("Error syncing task with expense: \(error)")
            }
        }
    }
    
    func updateTask(_ task: Task) {
        guard Auth.auth().currentUser != nil,
              let eventIndex = taskEvents.firstIndex(where: { $0.title == task.event }) else { return }
        
        var updatedTaskEvent = taskEvents[eventIndex]
        updatedTaskEvent.updateTask(task)
        
        do {
            try db.collection("taskEvents").document(task.event).setData(from: updatedTaskEvent)
            
            updateEventStats()
            syncTaskWithExpense(task)
        } catch {
            print("Error updating task: \(error)")
        }
    }
    
    func deleteTask(_ task: Task) {
        guard Auth.auth().currentUser != nil,
              let eventIndex = taskEvents.firstIndex(where: { $0.title == task.event }) else { return }
        
        var updatedTaskEvent = taskEvents[eventIndex]
        updatedTaskEvent.tasks.removeAll { $0.id == task.id }
        
        do {
            try db.collection("taskEvents").document(task.event).setData(from: updatedTaskEvent)
            
            // Also remove corresponding expense
            if let expenseIndex = expenseEvents.firstIndex(where: { $0.title == task.event }) {
                var updatedExpenseEvent = expenseEvents[expenseIndex]
                updatedExpenseEvent.expenses.removeAll { $0.name == task.name }
                
                try db.collection("expenseEvents").document(task.event).setData(from: updatedExpenseEvent)
            }
            
            updateEventStats()
        } catch {
            print("Error deleting task: \(error)")
        }
    }
    
    func addExpense(_ expense: Expense, to eventTitle: String) {
        guard Auth.auth().currentUser != nil else { return }
        
        if let eventIndex = expenseEvents.firstIndex(where: { $0.title == eventTitle }) {
            var updatedExpenseEvent = expenseEvents[eventIndex]
            updatedExpenseEvent.addExpense(expense)
            
            do {
                try db.collection("expenseEvents").document(eventTitle).setData(from: updatedExpenseEvent)
            } catch {
                print("Error adding expense: \(error)")
            }
        }
    }
    
    func addGuest(_ guest: Guest, to eventTitle: String) {
        guard Auth.auth().currentUser != nil,
              let eventIndex = events.firstIndex(where: { $0.title == eventTitle }) else { return }
        
        var updatedEvent = events[eventIndex]
        updatedEvent.guestCount += guest.count
        updatedEvent.guests.append(guest)
        
        do {
            try db.collection("events").document(updatedEvent.id.uuidString).setData(from: updatedEvent)
        } catch {
            print("Error adding guest: \(error)")
        }
    }
    
    func shareEventWithGroup(_ event: Event, group: Group) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Create a batch write
        let batch = db.batch()
        
        // Update the event in the owner's collection
        var updatedEvent = event
        updatedEvent.sharedWith = group.members.map { $0.uid }
        
        do {
            // 1. Update in owner's collection
            let ownerEventRef = db.collection("events").document(event.id.uuidString)
            try batch.setData(from: updatedEvent, forDocument: ownerEventRef)
            
            // 2. Create task and expense events for each group member
            for member in group.members where member.uid != currentUserId {
                let taskEvent = TaskEvent(
                    title: event.title,
                    tasks: [],
                    sharedWith: updatedEvent.sharedWith,
                    sharedGroups: updatedEvent.sharedGroups,
                    createdByUID: currentUserId
                )
                let taskEventRef = db.collection("taskEvents").document(event.title)
                try batch.setData(from: taskEvent, forDocument: taskEventRef)
                
                let expenseEvent = ExpenseEvent(
                    title: event.title,
                    totalAmount: 0,
                    expenses: [],
                    sharedWith: updatedEvent.sharedWith,
                    sharedGroups: updatedEvent.sharedGroups,
                    createdByUID: currentUserId
                )
                let expenseEventRef = db.collection("expenseEvents").document(event.title)
                try batch.setData(from: expenseEvent, forDocument: expenseEventRef)
            }
            
            // 3. Update the group with the shared event
            var updatedGroup = group
            if !updatedGroup.events.contains(event.id.uuidString) {
                updatedGroup.events.append(event.id.uuidString)
                try batch.setData(from: updatedGroup, forDocument: db.collection("groups").document(group.firestoreId ?? ""))
            }
            
            // Commit the batch
            batch.commit { error in
                if let error = error {
                    print("Error sharing event with group: \(error.localizedDescription)")
                } else {
                    print("Successfully shared event with group")
                }
            }
        } catch {
            print("Error preparing share batch: \(error.localizedDescription)")
        }
    }
    
    func refreshData() {
        isLoading = true
        invalidateCache()
        setupFirestoreListeners()
    }
    
    deinit {
        // Remove listeners when the store is deallocated
        queue.sync {
            listenerRegistrations.forEach { $0.remove() }
        }
    }
} 
