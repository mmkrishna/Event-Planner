import SwiftUI

struct HeaderView: View {
    let user: User
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false
    @State private var showingProfile = false
    
    var body: some View {
        HStack {
            Button(action: { showingProfile = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 50, height: 50)
                        Text(user.avatar)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(.purple)
                    }
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.role)
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                Button(action: {
                    showSignOutAlert = true
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.white)
                }
            }
            .font(.title3)
            .foregroundColor(.white)
        }
        .padding()
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(user: user)
        }
    }
}

#Preview {
    ZStack {
        Color(hue: 0.75, saturation: 1, brightness: 0.4)
        HeaderView(user: User(name: "Murali Krishna", role: "Administrator", avatar: "MK"))
    }
}
