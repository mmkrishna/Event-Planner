import SwiftUI

// Shared Card Styles
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .purple.opacity(0.2), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.1), lineWidth: 1)
            )
    }
}

// Shared Badge Style
struct BadgeStyle: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .cornerRadius(8)
    }
}

// Shared Icon Style
struct IconStyle: ViewModifier {
    let color: Color
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
    }
}

// Shared Action Button Style
struct ActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 44, height: 44)
    }
}

// Shared Gradient Icon Background
struct GradientIconBackground: View {
    let systemName: String
    
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.pink.opacity(0.8), .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: systemName)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
    }
}

// View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func badgeStyle(color: Color) -> some View {
        modifier(BadgeStyle(color: color))
    }
    
    func iconStyle(color: Color, size: CGFloat = 24) -> some View {
        modifier(IconStyle(color: color, size: size))
    }
    
    func actionButtonStyle() -> some View {
        modifier(ActionButtonStyle())
    }
}

struct BaseView<Content: View>: View {
    let user: User
    let content: Content
    
    init(user: User, @ViewBuilder content: () -> Content) {
        self.user = user
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(colors: [Color(hex: "CA007F"), Color(hex: "261B62")], 
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HeaderView(user: user)
                    .environmentObject(AuthViewModel.shared)
                
                // Content area with light background
                ScrollView {
                    VStack(spacing: 20) {
                        content
                    }
                    .padding(.top, 20)
                }
                .background(Color(hex: "FAF1FA"))
            }
        }
    }
}

#Preview {
    BaseView(user: User(name: "Murali Krishna", role: "Administrator", avatar: "MK")) {
        Text("Content goes here")
            .foregroundColor(.purple)
    }
} 
