import SwiftUI
import FirebaseAuth

struct ExpensesView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var description = ""
    @State private var amount = ""
    @State private var supplier = ""
    @State private var contact = ""
    @State private var selectedEvent = "Engagement"
    @State private var showingCreateExpenseSheet = false
    
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
    
    var totalExpenses: Double {
        eventStore.expenseEvents.reduce(0) { $0 + $1.totalAmount }
    }
    
    // Helper function to get initials
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }
            .map(String.init)
            .joined()
            .prefix(2)
            .uppercased()
        return String(initials)
    }
    
    private func createExpense() {
        guard !description.isEmpty,
              !amount.isEmpty,
              let amountValue = Double(amount.replacingOccurrences(of: ",", with: "")),
              amountValue.isFinite && !amountValue.isNaN && amountValue >= 0,
              !selectedEvent.isEmpty else { return }
        
        let currentUser = Auth.auth().currentUser
        let displayName = currentUser?.displayName ?? "Unknown"
        let newExpense = Expense(
            name: description,
            amount: amountValue,
            supplier: supplier,
            contact: contact,
            event: selectedEvent,
            createdBy: getInitials(from: displayName),
            createdByUID: currentUser?.uid ?? "",
            lastModifiedBy: getInitials(from: displayName),
            lastModifiedByUID: currentUser?.uid ?? "",
            lastModifiedDate: Date()
        )
        
        // Save to Firebase
        eventStore.addExpense(newExpense, to: selectedEvent)
        
        // Reset form
        description = ""
        amount = ""
        supplier = ""
        contact = ""
    }
    
    var body: some View {
        NavigationView {
            BaseView(user: currentUser) {
                VStack(spacing: 20) {
                    // Total Expenses Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Total Expenses")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("₹\(eventStore.formatAmount(totalExpenses))")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    
                    // Add Expenses Button
                    Button(action: {
                        showingCreateExpenseSheet = true
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Add New Expense")
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
                    
                    // Expense Lists per Event
                    ForEach(eventStore.expenseEvents, id: \.title) { event in
                        ExpenseEventCard(event: event)
                    }
                    
                    // Add some padding at the bottom for the tab bar
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateExpenseSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Expense Details")) {
                            TextField("Description", text: $description)
                            HStack {
                                Text("₹")
                                    .foregroundColor(.gray)
                                TextField("Amount", text: $amount)
                                    .keyboardType(.numberPad)
                            }
                            Picker("Event", selection: $selectedEvent) {
                                ForEach(eventStore.expenseEvents, id: \.title) { event in
                                    Text(event.title).tag(event.title)
                                }
                            }
                        }
                        
                        Section(header: Text("Supplier Information")) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.purple)
                                TextField("Supplier Name", text: $supplier)
                            }
                            
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.pink)
                                TextField("Contact Number", text: $contact)
                                    .keyboardType(.phonePad)
                            }
                        }
                    }
                    .navigationTitle("Add New Expense")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingCreateExpenseSheet = false
                        }
                        .foregroundColor(.purple),
                        trailing: Button("Add") {
                            createExpense()
                            showingCreateExpenseSheet = false
                        }
                        .disabled(description.isEmpty || amount.isEmpty || selectedEvent.isEmpty)
                        .foregroundColor((description.isEmpty || amount.isEmpty || selectedEvent.isEmpty) ? .gray : .pink)
                    )
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct ExpenseEventCard: View {
    let event: ExpenseEvent
    @State private var editingExpense: Expense? = nil
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: Expense? = nil
    @EnvironmentObject var eventStore: EventStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Event Header
            HStack {
                GradientIconBackground(systemName: "indianrupeesign")
                
                Text(event.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
                Spacer()
                Text("₹\(eventStore.formatAmount(event.totalAmount))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.purple)
            }
            
            if !event.expenses.isEmpty {
                // Expense Items
                VStack(spacing: 12) {
                    ForEach(event.expenses) { expense in
                        VStack(spacing: 10) {
                            // Expense Header
                            HStack {
                                Text(expense.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.purple)
                                Spacer()
                                Text("₹\(eventStore.formatAmount(expense.amount))")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.purple)
                                
                                // Action buttons
                                HStack(spacing: 4) {
                                    Button(action: {
                                        editingExpense = expense
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundColor(.purple)
                                            .font(.system(size: 24))
                                    }
                                    .frame(width: 32, height: 44)
                                    
                                    Button(action: {
                                        expenseToDelete = expense
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
                            
                            // Supplier Info
                            HStack {
                                Image(systemName: "person.fill")
                                    .iconStyle(color: .purple.opacity(0.7), size: 14)
                                Text(expense.supplier)
                                Spacer()
                                Image(systemName: "phone.fill")
                                    .iconStyle(color: .pink.opacity(0.7), size: 14)
                                Text(expense.contact)
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            
                            // User Info and Timestamp
                            HStack {
                                HStack(spacing: 4) {
                                    UserAvatar(initials: expense.createdBy, size: 24)
                                    Text(expense.lastModifiedDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                if expense.lastModifiedBy != expense.createdBy {
                                    Text("•")
                                        .foregroundColor(.gray)
                                    HStack(spacing: 4) {
                                        Text("edited by")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        UserAvatar(initials: expense.lastModifiedBy, size: 24)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "indianrupeesign.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.purple.opacity(0.3))
                    Text("No Expenses Yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
        .cardStyle()
        .alert("Delete Expense", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { 
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    eventStore.deleteExpense(expense, from: event.title)
                    expenseToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this expense? This action cannot be undone.")
        }
        .sheet(item: $editingExpense) { expense in
            EditExpenseSheet(expense: expense) { updatedExpense in
                if let eventIndex = eventStore.expenseEvents.firstIndex(where: { $0.title == event.title }) {
                    eventStore.expenseEvents[eventIndex].updateExpense(updatedExpense)
                }
                editingExpense = nil
            }
        }
    }
}

struct EditExpenseSheet: View {
    let expense: Expense
    let onSave: (Expense) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String
    @State private var editedAmount: String
    @State private var editedSupplier: String
    @State private var editedContact: String
    @State private var showInvalidAmountAlert = false
    
    init(expense: Expense, onSave: @escaping (Expense) -> Void) {
        self.expense = expense
        self.onSave = onSave
        _editedName = State(initialValue: expense.name)
        _editedAmount = State(initialValue: String(format: "%.0f", expense.amount))
        _editedSupplier = State(initialValue: expense.supplier)
        _editedContact = State(initialValue: expense.contact)
    }
    
    private func validateAndSave() {
        let cleanAmount = editedAmount.replacingOccurrences(of: ",", with: "")
        if let amount = Double(cleanAmount),
           amount.isFinite && !amount.isNaN && amount >= 0 {
            let currentUser = Auth.auth().currentUser
            let displayName = currentUser?.displayName ?? "Unknown"
            let updatedExpense = Expense(
                name: editedName,
                amount: amount,
                supplier: editedSupplier,
                contact: editedContact,
                event: expense.event,
                createdBy: expense.createdBy,
                createdByUID: expense.createdByUID,
                lastModifiedBy: getInitials(from: displayName),
                lastModifiedByUID: currentUser?.uid ?? "",
                lastModifiedDate: Date()
            )
            onSave(updatedExpense)
            dismiss()
        } else {
            showInvalidAmountAlert = true
        }
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }
            .map(String.init)
            .joined()
            .prefix(2)
            .uppercased()
        return String(initials)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Description", text: $editedName)
                    HStack {
                        Text("₹")
                            .foregroundColor(.gray)
                        TextField("Amount", text: $editedAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Supplier Information")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.purple)
                        TextField("Supplier Name", text: $editedSupplier)
                    }
                    
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.pink)
                        TextField("Contact Number", text: $editedContact)
                            .keyboardType(.phonePad)
                    }
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.purple),
                trailing: Button("Save") {
                    validateAndSave()
                }
                .disabled(editedName.isEmpty || editedAmount.isEmpty)
                .foregroundColor((editedName.isEmpty || editedAmount.isEmpty) ? .gray : .pink)
            )
            .alert("Invalid Amount", isPresented: $showInvalidAmountAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid amount greater than or equal to 0.")
            }
        }
        .presentationDetents([.medium])
    }
}

// Preview helpers
#Preview {
    ExpensesView()
        .environmentObject(EventStore.preview)
        .environmentObject(AuthViewModel.preview)
        .environmentObject(ProfileViewModel.preview)
}

// Replace the current preview extensions with these:
extension EventStore {
    static var preview: EventStore {
        let store = EventStore.shared
        
        // Use a dispatch group to ensure data is loaded before preview
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.global().async {
            // Set mock data
            store.expenseEvents = [
                ExpenseEvent(
                    id: UUID(),
                    title: "Test Event",
                    totalAmount: 1000,
                    expenses: [
                        Expense(
                            id: UUID(),
                            name: "Test Expense",
                            amount: 1000,
                            supplier: "Test Supplier",
                            contact: "1234567890",
                            event: "Test Event",
                            createdBy: "TS",
                            createdByUID: "test-uid",
                            lastModifiedBy: "TS",
                            lastModifiedByUID: "test-uid",
                            lastModifiedDate: Date()
                        )
                    ],
                    sharedWith: [],
                    sharedGroups: [],
                    createdByUID: "test-uid"
                )
            ]
            
            // Add more mock data for other collections
            store.events = [
                Event(
                    id: UUID(),
                    title: "Test Event",
                    date: Date(),
                    time: "10:00 AM",
                    venue: "Test Venue",
                    completedTasks: 2,
                    totalTasks: 5,
                    guestCount: 10,
                    guests: [],
                    createdBy: "Test User",
                    createdByUID: "test-uid",
                    sharedWith: [],
                    sharedGroups: []
                )
            ]
            
            store.taskEvents = [
                TaskEvent(
                    title: "Test Event",
                    tasks: [
                        Task(
                            id: UUID(),
                            name: "Test Task",
                            supplier: "Test Supplier",
                            contact: "1234567890",
                            event: "Test Event",
                            isCompleted: true,
                            amount: "500",
                            createdBy: "TS",
                            createdByUID: "test-uid",
                            lastModifiedBy: "TS",
                            lastModifiedByUID: "test-uid",
                            lastModifiedDate: Date()
                        )
                    ],
                    sharedWith: [],
                    sharedGroups: [],
                    createdByUID: "test-uid"
                )
            ]
            
            group.leave()
        }
        
        // Wait for mock data to be set (with timeout)
        _ = group.wait(timeout: .now() + 1.0)
        
        return store
    }
}

extension AuthViewModel {
    static var preview: AuthViewModel {
        let auth = AuthViewModel.shared
        auth.isAuthenticated = true
        return auth
    }
}

extension ProfileViewModel {
    static var preview: ProfileViewModel {
        let profile = ProfileViewModel.shared
        
        // Use a dispatch group to ensure data is loaded before preview
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.global().async {
            // Set mock data
            profile.groups = [
                Group(
                    id: UUID(),
                    name: "Test Group",
                    createdBy: "Test User",
                    createdByUID: "test-uid",
                    members: [
                        Group.GroupMember(
                            id: UUID(),
                            uid: "test-uid",
                            name: "Test User",
                            email: "test@example.com",
                            role: "admin",
                            dateAdded: Date()
                        )
                    ],
                    memberIds: ["test-uid"],
                    events: [],
                    dateCreated: Date()
                )
            ]
            
            group.leave()
        }
        
        // Wait for mock data to be set (with timeout)
        _ = group.wait(timeout: .now() + 1.0)
        
        return profile
    }
} 