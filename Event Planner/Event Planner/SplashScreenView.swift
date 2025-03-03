//
//  SplashScreenView.swift
//  Event Planner
//
//  Created by Murali Krishna on 13/02/2025.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.1 // Start small
    
    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            Image("MKLaunchscreen")
                .resizable()
                .scaledToFit()
                .scaleEffect(scale) // Apply scale animation
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5)) { // Smooth animation
                        scale = 0.7 // Scale to full size
                    }
                }
        }
    }
}

#Preview {
    SplashScreenView()
}
