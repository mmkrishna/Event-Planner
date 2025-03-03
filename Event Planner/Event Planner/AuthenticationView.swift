import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showRegistration = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var rememberMe = false
    @Published var isLoading = false
    
    static let shared = AuthViewModel()
    
    private init() {
        // Load remember me preference
        rememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
        
        // Check if user is already signed in
        if let _ = Auth.auth().currentUser {
            isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            showError = true
            return
        }
        
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                } else if let user = result?.user {
                    // Update user document in Firestore
                    let db = Firestore.firestore()
                    let userData = [
                        "email": email,
                        "name": user.displayName ?? "",
                        "uid": user.uid,
                        "lastLogin": Timestamp(date: Date())
                    ]
                    
                    db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                        if let error = error {
                            print("Error updating user document: \(error.localizedDescription)")
                        }
                    }
                    
                    self?.isAuthenticated = true
                    // Save credentials if remember me is enabled
                    if let self = self, self.rememberMe {
                        UserDefaults.standard.set(email, forKey: "savedEmail")
                        // Note: We don't save the password for security reasons
                    }
                }
            }
        }
    }
    
    func updateRememberMe(_ value: Bool) {
        rememberMe = value
        UserDefaults.standard.set(value, forKey: "rememberMe")
        if !value {
            // Clear saved email if remember me is disabled
            UserDefaults.standard.removeObject(forKey: "savedEmail")
        }
    }
    
    func signUp(email: String, password: String, name: String) {
        // Validate inputs
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        // Validate password strength
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showError = true
            return
        }
        
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                } else if let user = result?.user {
                    // Create user profile
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = name
                    changeRequest.commitChanges { error in
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            self?.showError = true
                        }
                    }
                    
                    // Create user document in Firestore
                    let db = Firestore.firestore()
                    let userData = [
                        "email": email,
                        "name": name,
                        "uid": user.uid,
                        "createdAt": Timestamp(date: Date()),
                        "lastLogin": Timestamp(date: Date())
                    ]
                    
                    db.collection("users").document(user.uid).setData(userData) { error in
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            self?.showError = true
                        }
                    }
                    
                    self?.isAuthenticated = true
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // Helper function to validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    
    init() {
        // Load saved email if remember me was enabled
        _email = State(initialValue: UserDefaults.standard.string(forKey: "savedEmail") ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(colors: [Color(hex: "CA007F"), Color(hex: "261B62")],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Logo and App Name
                    VStack(spacing: 8) {
                        Image("MK Logo white")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                        
                        Text("EventSync")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Event Planner")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 40)
                    
                    // Form Fields
                    VStack(spacing: 15) {
                        if viewModel.showRegistration {
                            TextField("Name", text: $name)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.name)
                                .autocapitalization(.words)
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(AuthTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(AuthTextFieldStyle())
                            .textContentType(viewModel.showRegistration ? .newPassword : .password)
                        
                        if !viewModel.showRegistration {
                            Toggle(isOn: Binding(
                                get: { viewModel.rememberMe },
                                set: { viewModel.updateRememberMe($0) }
                            )) {
                                Text("Remember Me")
                                    .foregroundColor(.white)
                            }
                            .tint(.pink)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Action Button
                    Button(action: {
                        if viewModel.showRegistration {
                            viewModel.signUp(email: email, password: password, name: name)
                        } else {
                            viewModel.signIn(email: email, password: password)
                        }
                    }) {
                        ZStack {
                            Text(viewModel.showRegistration ? "Sign Up" : "Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(colors: [.pink, .purple],
                                                 startPoint: .leading,
                                                 endPoint: .trailing)
                                )
                                .cornerRadius(25)
                                .padding(.horizontal, 32)
                                .opacity(viewModel.isLoading ? 0 : 1)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.top, 20)
                    
                    // Toggle Button
                    Button(action: {
                        withAnimation {
                            viewModel.showRegistration.toggle()
                            // Clear fields when switching
                            email = ""
                            password = ""
                            name = ""
                        }
                    }) {
                        Text(viewModel.showRegistration ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                    .disabled(viewModel.isLoading)
                    
                    Spacer()
                    
                    // Credit text at bottom
                    Text("by Murali Krishna Manikyam")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 20)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
            .foregroundColor(.purple)
            .tint(.purple)
            .accentColor(.purple)
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel.shared)
} 