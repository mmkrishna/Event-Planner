import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var eventStore: EventStore
    @State private var selectedTab = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(Color(hue: 0.75, saturation: 1, brightness: 0.6))
        
        // Customize tab bar item colors
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.65)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.65)]
        
        // Use this appearance for both standard and scrollEdge
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .background(.black)
            } else if !authViewModel.isAuthenticated {
                AuthenticationView()
            } else {
                ZStack {
                    TabView(selection: $selectedTab) {
                        HomeView()
                            .tabItem {
                                Image(systemName: "house.fill")
                                Text("Home")
                            }
                            .tag(0)
                        
                        TimelineView()
                            .tabItem {
                                Image(systemName: "calendar")
                                Text("Timeline")
                            }
                            .tag(1)
                        
                        ExpensesView()
                            .tabItem {
                                Image(systemName: "dollarsign.circle")
                                Text("Expenses")
                            }
                            .tag(2)
                        
                        ChecklistView()
                            .tabItem {
                                Image(systemName: "checklist")
                                Text("Checklist")
                            }
                            .tag(3)
                        
                        GuestsView()
                            .tabItem {
                                Image(systemName: "person.2")
                                Text("Guests")
                            }
                            .tag(4)
                    }
                    .tint(.white)
                    .onChange(of: selectedTab) { oldValue, newValue in
                        // Perform any necessary actions when tab changes
                        hapticFeedback(style: .light)
                    }
                    
                    // Show loading indicator when data is being fetched
                    if eventStore.isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .overlay {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSplash = false
                }
            }
        }
    }
    
    // Haptic feedback function
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel.shared)
        .environmentObject(EventStore.shared)
        .environmentObject(ProfileViewModel.shared)
}
