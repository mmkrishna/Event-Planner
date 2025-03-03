import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    let user: User
    @StateObject private var viewModel = ProfileViewModel.shared
    @State private var newGroupName = ""
    @State private var newMemberEmail = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // User Profile Section
                VStack(spacing: 16) {
                    Text(user.avatar)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.purple)
                        .frame(width: 100, height: 100)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .purple.opacity(0.3), radius: 5)
                    
                    Text(user.name)
                        .font(.title2)
                        .foregroundColor(.purple)
                    
                    Text(user.role)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                
                // Groups Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("My Groups")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.showingCreateGroupSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.pink)
                                .font(.title2)
                        }
                    }
                    
                    if viewModel.groups.isEmpty {
                        Text("No groups yet")
                            .foregroundColor(.gray)
                            .italic()
                            .padding()
                    } else {
                        ForEach(viewModel.groups) { group in
                            GroupCard(group: group)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showingCreateGroupSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Group Details")) {
                        TextField("Group Name", text: $newGroupName)
                    }
                }
                .navigationTitle("Create Group")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        viewModel.showingCreateGroupSheet = false
                    },
                    trailing: Button("Create") {
                        viewModel.createGroup(name: newGroupName)
                        newGroupName = ""
                        viewModel.showingCreateGroupSheet = false
                    }
                    .disabled(newGroupName.isEmpty)
                )
            }
            .presentationDetents([.medium])
        }
    }
}

struct GroupCard: View {
    let group: Group
    @StateObject private var viewModel = ProfileViewModel.shared
    @State private var showingAddMemberSheet = false
    @State private var newMemberEmail = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button(action: {
                    showingAddMemberSheet = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.pink)
                }
            }
            
            Text("Created by: \(group.createdBy)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("Members (\(group.members.count))")
                .font(.subheadline)
                .foregroundColor(.purple)
                .padding(.top, 4)
            
            ForEach(group.members, id: \.id) { member in
                HStack {
                    Text(member.name)
                        .font(.subheadline)
                    Spacer()
                    Text(member.role)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .purple.opacity(0.1), radius: 5)
        .sheet(isPresented: $showingAddMemberSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Add Member")) {
                        TextField("Email", text: $newMemberEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }
                .navigationTitle("Add Member")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingAddMemberSheet = false
                    },
                    trailing: Button("Add") {
                        viewModel.addMemberToGroup(newMemberEmail, group: group)
                        newMemberEmail = ""
                        showingAddMemberSheet = false
                    }
                    .disabled(newMemberEmail.isEmpty)
                )
            }
            .presentationDetents([.medium])
        }
    }
} 