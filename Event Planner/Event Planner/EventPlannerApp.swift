import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure appearance
        configureAppAppearance()
        
        return true
    }
    
    private func configureAppAppearance() {
        // Configure tab bar appearance
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
        
        // Configure navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color(hue: 0.75, saturation: 1, brightness: 0.6))
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white
    }
}

@main
struct EventPlannerApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Initialize shared instances at app level
    @StateObject private var authViewModel = AuthViewModel.shared
    @StateObject private var eventStore = EventStore.shared
    @StateObject private var profileViewModel = ProfileViewModel.shared
    
    @State private var showLaunchScreen = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(authViewModel)
                    .environmentObject(eventStore)
                    .environmentObject(profileViewModel)
                    .onAppear {
                        // Delay data loading until after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            if authViewModel.isAuthenticated {
                                eventStore.refreshData()
                                profileViewModel.setupGroupListener()
                            }
                        }
                    }
                
                if showLaunchScreen {
                    LaunchScreenView(showLaunchScreen: $showLaunchScreen)
                        .transition(.opacity)
                }
            }
        }
    }
} 