import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @Binding var showLaunchScreen: Bool
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Image("MKLaunchscreen")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                    .scaleEffect(isAnimating ? 1.0 : 0.7)
                    .opacity(isAnimating ? 1 : 0)
                
                Text("Murali Krishna")
                    .font(.footnote)
                    .foregroundColor(Color(.gray))
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: 200)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                isAnimating = true
            }
            
            // Dismiss the launch screen after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showLaunchScreen = false
                }
            }
        }
    }
} 
