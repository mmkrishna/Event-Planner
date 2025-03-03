import SwiftUI

struct UserAvatar: View {
    let initials: String
    let size: CGFloat
    
    private var backgroundColor: Color {
        // Generate a consistent color based on initials
        let hash = initials.unicodeScalars.reduce(0) { $0 + $1.value }
        let hue = Double(hash % 7) / 7.0  // 7 different base hues
        return Color(hue: hue, saturation: 0.7, brightness: 0.9)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
} 