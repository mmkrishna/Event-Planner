import SwiftUI
import FirebaseFirestore

struct User: Codable {
    let name: String
    let role: String
    let avatar: String
}

struct Guest: Identifiable, Equatable, Codable {
    @DocumentID var firestoreId: String?
    var id = UUID()
    var name: String
    var count: Int
    var event: String
    var isSelected: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case firestoreId
        case id
        case name
        case count
        case event
        case isSelected
    }
    
    static func == (lhs: Guest, rhs: Guest) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.count == rhs.count &&
        lhs.event == rhs.event &&
        lhs.isSelected == rhs.isSelected
    }
}

struct SharedUser: Codable, Equatable {
    var email: String
    var uid: String
    var permissions: [String]  // ["edit", "view"]
    var dateShared: Date
    
    static func == (lhs: SharedUser, rhs: SharedUser) -> Bool {
        lhs.uid == rhs.uid
    }
}

struct Event: Identifiable, Equatable, Codable, Hashable {
    @DocumentID var firestoreId: String?
    var id: UUID
    var title: String
    var date: Date
    var time: String
    var venue: String
    var completedTasks: Int
    var totalTasks: Int
    var guestCount: Int
    var guests: [Guest]
    var createdBy: String  // User who created the event
    var createdByUID: String  // User's Firebase UID
    var sharedWith: [String]  // Array of user IDs who have access to this event
    var sharedGroups: [String]  // Array of group IDs that have access to this event
    
    enum CodingKeys: String, CodingKey {
        case firestoreId
        case id
        case title
        case date
        case time
        case venue
        case completedTasks
        case totalTasks
        case guestCount
        case guests
        case createdBy
        case createdByUID
        case sharedWith
        case sharedGroups
    }
    
    init(id: UUID = UUID(), title: String, date: Date, time: String, venue: String = "", completedTasks: Int = 0, totalTasks: Int = 0, guestCount: Int = 0, guests: [Guest] = [], createdBy: String = "", createdByUID: String = "", sharedWith: [String] = [], sharedGroups: [String] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.time = time
        self.venue = venue
        self.completedTasks = completedTasks
        self.totalTasks = totalTasks
        self.guestCount = guestCount
        self.guests = guests
        self.createdBy = createdBy
        self.createdByUID = createdByUID
        self.sharedWith = sharedWith
        self.sharedGroups = sharedGroups
    }
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.date == rhs.date &&
        lhs.time == rhs.time &&
        lhs.venue == rhs.venue &&
        lhs.completedTasks == rhs.completedTasks &&
        lhs.totalTasks == rhs.totalTasks &&
        lhs.guestCount == rhs.guestCount &&
        lhs.guests == rhs.guests &&
        lhs.createdBy == rhs.createdBy &&
        lhs.createdByUID == rhs.createdByUID &&
        lhs.sharedWith == rhs.sharedWith &&
        lhs.sharedGroups == rhs.sharedGroups
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Task: Identifiable, Codable {
    @DocumentID var firestoreId: String?
    var id = UUID()
    var name: String
    var supplier: String
    var contact: String
    var event: String
    var isCompleted: Bool
    var amount: String
    var createdBy: String  // User who created the task
    var createdByUID: String  // User's Firebase UID
    var lastModifiedBy: String  // User who last modified the task
    var lastModifiedByUID: String  // User's Firebase UID
    var lastModifiedDate: Date  // Last modification timestamp
    
    enum CodingKeys: String, CodingKey {
        case firestoreId
        case id
        case name
        case supplier
        case contact
        case event
        case isCompleted
        case amount
        case createdBy
        case createdByUID
        case lastModifiedBy
        case lastModifiedByUID
        case lastModifiedDate
    }
    
    func updated(name: String, supplier: String, contact: String, amount: String) -> Task {
        var copy = self
        copy.name = name
        copy.supplier = supplier
        copy.contact = contact
        copy.amount = amount
        return copy
    }
}

struct Expense: Identifiable, Codable {
    @DocumentID var firestoreId: String?
    var id = UUID()
    var name: String
    var amount: Double
    var supplier: String
    var contact: String
    var event: String
    var createdBy: String  // User who created the expense
    var createdByUID: String  // User's Firebase UID
    var lastModifiedBy: String  // User who last modified the expense
    var lastModifiedByUID: String  // User's Firebase UID
    var lastModifiedDate: Date  // Last modification timestamp
    
    enum CodingKeys: String, CodingKey {
        case firestoreId
        case id
        case name
        case amount
        case supplier
        case contact
        case event
        case createdBy
        case createdByUID
        case lastModifiedBy
        case lastModifiedByUID
        case lastModifiedDate
    }
}

struct TaskEvent: Codable {
    @DocumentID var firestoreId: String?
    var title: String
    var tasks: [Task]
    var sharedWith: [String]  // Array of user IDs who have access
    var sharedGroups: [String]  // Array of group IDs that have access
    var createdByUID: String  // User who created the event
    
    enum CodingKeys: String, CodingKey {
        case firestoreId
        case title
        case tasks
        case sharedWith
        case sharedGroups
        case createdByUID
    }
    
    var completedTasks: Int {
        tasks.filter { $0.isCompleted }.count
    }
    
    var totalTasks: Int {
        tasks.count
    }
    
    var totalBudget: Double {
        tasks.reduce(0) { total, task in
            total + (Double(task.amount.replacingOccurrences(of: ",", with: "")) ?? 0)
        }
    }
    
    mutating func addTask(_ task: Task) {
        tasks.append(task)
    }
    
    mutating func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }
}

struct ExpenseEvent: Identifiable, Codable {
    @DocumentID var firestoreId: String?
    var id = UUID()
    var title: String
    var totalAmount: Double
    var expenses: [Expense]
    var sharedWith: [String]  // Array of user IDs who have access
    var sharedGroups: [String]  // Array of group IDs that have access
    var createdByUID: String  // User who created the event
    
    enum CodingKeys: String, CodingKey {
        case firestoreId
        case id
        case title
        case totalAmount
        case expenses
        case sharedWith
        case sharedGroups
        case createdByUID
    }
    
    mutating func addExpense(_ expense: Expense) {
        expenses.append(expense)
        totalAmount += expense.amount
    }
    
    mutating func removeExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            totalAmount -= expenses[index].amount
            expenses.remove(at: index)
        }
    }
    
    mutating func updateExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            totalAmount -= expenses[index].amount
            totalAmount += expense.amount
            expenses[index] = expense
        }
    }
}

struct Group: Identifiable, Codable {
    @DocumentID var firestoreId: String?
    var id = UUID()
    var name: String
    var createdBy: String  // User who created the group
    var createdByUID: String  // User's Firebase UID
    var members: [GroupMember]
    var memberIds: [String]  // Array of member UIDs for easy querying
    var events: [String]  // Array of event IDs shared with this group
    var dateCreated: Date
    
    struct GroupMember: Codable, Identifiable {
        var id = UUID()
        var uid: String
        var name: String
        var email: String
        var role: String  // "admin" or "member"
        var dateAdded: Date
    }
} 
