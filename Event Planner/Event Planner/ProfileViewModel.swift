import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ProfileViewModel: ObservableObject {
    @Published var groups: [Group] = []
    @Published var showingCreateGroupSheet = false
    @Published var showingAddMemberSheet = false
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    static let shared = ProfileViewModel()
    
    private init() {
        setupGroupListener()
    }
    
    func setupGroupListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Remove any existing listener
        listenerRegistration?.remove()
        
        // Listen for groups where user is a member
        listenerRegistration = db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching groups: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.groups = documents.compactMap { document -> Group? in
                    try? document.data(as: Group.self)
                }
            }
    }
    
    func createGroup(name: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let member = Group.GroupMember(
            uid: currentUser.uid,
            name: currentUser.displayName ?? "Unknown",
            email: currentUser.email ?? "",
            role: "admin",
            dateAdded: Date()
        )
        
        let newGroup = Group(
            name: name,
            createdBy: currentUser.displayName ?? "Unknown",
            createdByUID: currentUser.uid,
            members: [member],
            memberIds: [currentUser.uid],
            events: [],
            dateCreated: Date()
        )
        
        do {
            try db.collection("groups").document()
                .setData(from: newGroup)
        } catch {
            print("Error creating group: \(error)")
        }
    }
    
    func addMemberToGroup(_ email: String, group: Group) {
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
                
                let userId = document.documentID
                let displayName = document["name"] as? String ?? "Unknown"
                
                // Create new member
                let newMember = Group.GroupMember(
                    uid: userId,
                    name: displayName,
                    email: email,
                    role: "member",
                    dateAdded: Date()
                )
                
                // Update group
                var updatedGroup = group
                if !updatedGroup.memberIds.contains(userId) {
                    updatedGroup.members.append(newMember)
                    updatedGroup.memberIds.append(userId)
                    
                    // Update in Firestore
                    do {
                        try self?.db.collection("groups").document(group.firestoreId ?? "")
                            .setData(from: updatedGroup)
                    } catch {
                        print("Error adding member to group: \(error)")
                    }
                }
            }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
} 