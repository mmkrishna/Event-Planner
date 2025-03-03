import SwiftUI
import FirebaseAuth

struct ChecklistView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var taskName = ""
    @State private var supplier = ""
    @State private var contact = ""
    @State private var selectedEvent = ""
    @State private var amount = ""
    @State private var showEventPicker = false
    @State private var showingSuccessMessage = false
    @State private var editingTask: Task? = nil
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: Task? = nil
    
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
                VStack(spacing: 24) {
                    // Create New Task Button
                    Button(action: {
                        if let firstEvent = eventStore.events.first {
                            let currentUser = Auth.auth().currentUser
                            let displayName = currentUser?.displayName ?? "Unknown"
                            editingTask = Task(
                                name: "",
                                supplier: "",
                                contact: "",
                                event: firstEvent.title,
                                isCompleted: false,
                                amount: "",
                                createdBy: getInitials(from: displayName),
                                createdByUID: currentUser?.uid ?? "",
                                lastModifiedBy: getInitials(from: displayName),
                                lastModifiedByUID: currentUser?.uid ?? "",
                                lastModifiedDate: Date()
                            )
                        }
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Create New Task")
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
                    
                    // Tasks grouped by Event
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(eventStore.events) { event in
                                VStack(alignment: .leading, spacing: 16) {
                                    // Event Header
                                    HStack {
                                        GradientIconBackground(systemName: "star.fill")
                                        Text(event.title)
                                            .font(.headline)
                                            .foregroundColor(.purple)
                                        Spacer()
                                        Text("\(event.completedTasks)/\(event.totalTasks)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal)
                                    
                                    // Tasks for this event
                                    let eventTasks = eventStore.taskEvents
                                        .first(where: { $0.title == event.title })?
                                        .tasks ?? []
                                    
                                    if eventTasks.isEmpty {
                                        Text("No tasks yet")
                                            .foregroundColor(.gray)
                                            .italic()
                                            .padding()
                                    } else {
                                        VStack(spacing: 12) {
                                            ForEach(eventTasks) { task in
                                                TaskRow(task: task, 
                                                       onToggle: toggleTaskCompletion, 
                                                       onEdit: { task in
                                                           editingTask = task
                                                       }, 
                                                       onDelete: { task in
                                                           taskToDelete = task
                                                           showingDeleteAlert = true
                                                       })
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    isPresented: Binding(
                        get: { editingTask != nil },
                        set: { if !$0 { editingTask = nil } }
                    ),
                    task: task,
                    onSave: { updatedTask in
                        updateTask(updatedTask)
                        editingTask = nil
                    }
                )
            }
            .alert("Delete Task", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { 
                    taskToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                        taskToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
        }
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        eventStore.updateTask(updatedTask)
        eventStore.updateEventStats()
    }
    
    private func deleteTask(_ task: Task) {
        eventStore.deleteTask(task)
    }
    
    private func updateTask(_ task: Task) {
        eventStore.updateTask(task)
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map(String.init)
        return initials.joined()
    }
}

struct TaskRow: View {
    let task: Task
    let onToggle: (Task) -> Void
    let onEdit: (Task) -> Void
    let onDelete: (Task) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: { onToggle(task) }) {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundColor(task.isCompleted ? .purple : .black)
                }
                .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    
                    HStack(spacing: 4) {
                        UserAvatar(initials: task.createdBy, size: 20)
                        Text(task.lastModifiedDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text("₹ \(task.amount)")
                    .font(.system(size: 16))
                
                // Action Buttons
                HStack(spacing: 4) {
                    Button(action: { 
                        onEdit(task)
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.purple)
                            .font(.system(size: 24))
                    }
                    .frame(width: 32, height: 44)
                    
                    Button(action: { 
                        onDelete(task)
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
            
            // Supplier Info Bar
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                Text(task.supplier)
                    .foregroundColor(.white)
                    .font(.system(size: 14, design: .default))
                    .italic()
                Spacer()
                Image(systemName: "phone.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                Text(task.contact)
                    .foregroundColor(.white)
                    .font(.system(size: 14, design: .default))
                    .italic()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.8))
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct EditTaskSheet: View {
    @Binding var isPresented: Bool
    let task: Task
    let onSave: (Task) -> Void
    @State private var editedName: String
    @State private var editedSupplier: String
    @State private var editedContact: String
    @State private var editedAmount: String
    @State private var selectedEvent: String
    @State private var showInvalidAmountAlert = false
    @EnvironmentObject var eventStore: EventStore
    
    init(isPresented: Binding<Bool>, task: Task, onSave: @escaping (Task) -> Void) {
        self._isPresented = isPresented
        self.task = task
        self.onSave = onSave
        
        _editedName = State(initialValue: task.name)
        _editedSupplier = State(initialValue: task.supplier)
        _editedContact = State(initialValue: task.contact)
        _editedAmount = State(initialValue: task.amount)
        _selectedEvent = State(initialValue: task.event)
    }
    
    private func validateAndSave() {
        let cleanAmount = editedAmount.replacingOccurrences(of: ",", with: "")
        if let _ = Double(cleanAmount) {
            let currentUser = Auth.auth().currentUser
            let displayName = currentUser?.displayName ?? "Unknown"
            let updatedTask = Task(
                id: task.id,
                name: editedName,
                supplier: editedSupplier,
                contact: editedContact,
                event: selectedEvent,
                isCompleted: task.isCompleted,
                amount: formatAmount(editedAmount),
                createdBy: task.createdBy.isEmpty ? getInitials(from: displayName) : task.createdBy,
                createdByUID: task.createdByUID.isEmpty ? (currentUser?.uid ?? "") : task.createdByUID,
                lastModifiedBy: getInitials(from: displayName),
                lastModifiedByUID: currentUser?.uid ?? "",
                lastModifiedDate: Date()
            )
            onSave(updatedTask)
            isPresented = false
        } else {
            showInvalidAmountAlert = true
        }
    }
    
    private func formatAmount(_ amountString: String) -> String {
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: "")
        if let amount = Double(cleanAmount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: amount)) ?? "0"
        }
        return amountString
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map(String.init)
        return initials.joined()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Name", text: $editedName)
                    HStack {
                        Text("₹")
                            .foregroundColor(.gray)
                        TextField("Amount", text: $editedAmount)
                            .keyboardType(.numberPad)
                    }
                    Picker("Event", selection: $selectedEvent) {
                        ForEach(eventStore.events) { event in
                            Text(event.title).tag(event.title)
                        }
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
            .navigationTitle(task.name.isEmpty ? "Create Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.purple),
                trailing: Button(task.name.isEmpty ? "Create" : "Save") {
                    validateAndSave()
                }
                .disabled(editedName.isEmpty || selectedEvent.isEmpty || editedAmount.isEmpty)
                .foregroundColor((editedName.isEmpty || selectedEvent.isEmpty || editedAmount.isEmpty) ? .gray : .pink)
            )
        }
        .presentationDetents([.medium])
        .onAppear {
            // If no event is selected and there are events available, select the first one
            if selectedEvent.isEmpty && !eventStore.events.isEmpty {
                selectedEvent = eventStore.events[0].title
            }
        }
    }
}

#Preview {
    ChecklistView()
} 