//
//  BackgroundView.swift
//  ChefAcademy
//
//  A reusable background component that shows a small decorative
//  illustration in the bottom-right corner of the screen.
//
//  Usage:
//    ZStack {
//        BackgroundView(imageName: "bg_cottage")
//        // Your content here
//    }
//

import SwiftUI

// MARK: - Background View

struct BackgroundView: View {
    /// The name of the background image in Assets
    let imageName: String

    /// Overall opacity of the background image
    var opacity: Double = 0.8

    /// Size of the image as a fraction of screen width (0.4 = 40% on iPad, +30% on iPhone)
    var imageScale: CGFloat = 0.4

    /// The background color
    var backgroundColor: Color = Color.AppTheme.cream

    /// Detect device size class
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Base background color
                backgroundColor
                    .ignoresSafeArea()

                // Background image as small decorative illustration
                backgroundImage(in: geometry)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background Image

    func backgroundImage(in geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        // Add 25% for mobile (compact) devices
        let adjustedScale = sizeClass == .compact ? imageScale + 0.25 : imageScale
        let imageSize = screenWidth * adjustedScale
        // Move 10% to the right and 5% down on mobile
        let horizontalOffset = sizeClass == .compact ? screenWidth * 0.1 : 0
        let verticalOffset = sizeClass == .compact ? screenHeight * 0.05 : 0

        return Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageSize)
            .opacity(opacity)
            .padding(.trailing, 20)
            .offset(x: horizontalOffset, y: verticalOffset)
    }
}

// MARK: - Cottage Background (Preset)
//
// A convenient preset for the mushroom cottage background
//

struct CottageBackground: View {
    var opacity: Double = 0.8

    var body: some View {
        BackgroundView(
            imageName: "bg_cottage",
            opacity: opacity,
            backgroundColor: Color.AppTheme.cream
        )
    }
}

// MARK: - Background Modifier
//
// Apply as a view modifier for cleaner syntax
//

struct CottageBackgroundModifier: ViewModifier {
    var opacity: Double = 0.8

    func body(content: Content) -> some View {
        ZStack {
            CottageBackground(opacity: opacity)
            content
        }
    }
}

extension View {
    /// Adds the cottage background behind the view
    func cottageBackground(opacity: Double = 0.8) -> some View {
        modifier(CottageBackgroundModifier(opacity: opacity))
    }
}

// MARK: - Animated Background (Optional)
//
// Background with subtle floating animation
//

struct AnimatedBackgroundView: View {
    let imageName: String
    var opacity: Double = 0.8
    var imageScale: CGFloat = 0.4
    var backgroundColor: Color = Color.AppTheme.cream

    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            // Add 20% for mobile (compact) devices
            let adjustedScale = sizeClass == .compact ? imageScale + 0.2 : imageScale
            let imageSize = screenWidth * adjustedScale
            // Move 10% to the right and 5% down on mobile
            let horizontalOffset = sizeClass == .compact ? screenWidth * 0.1 : 0
            let verticalOffset = sizeClass == .compact ? screenHeight * 0.05 : 0

            ZStack(alignment: .bottomTrailing) {
                backgroundColor
                    .ignoresSafeArea()

                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize)
                    .opacity(opacity)
                    .padding(.trailing, 20)
                    .offset(x: horizontalOffset, y: verticalOffset + floatOffset)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                floatOffset = -8
            }
        }
    }
}

// MARK: - Preview

#Preview("Cottage Background") {
    ZStack {
        CottageBackground()

        VStack {
            Text("Content on the left")
                .font(.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            Spacer()
        }
        .padding()
    }
}

#Preview("Larger Cottage") {
    ZStack {
        BackgroundView(
            imageName: "bg_cottage",
            imageScale: 0.5
        )

        Text("Larger illustration")
            .font(.title)
            .foregroundColor(Color.AppTheme.darkBrown)
    }
}

#Preview("Using Modifier") {
    VStack {
        Text("Hello World")
            .font(.largeTitle)
        Spacer()
    }
    .padding()
    .cottageBackground()
}
