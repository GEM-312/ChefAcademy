//
//  PlotView.swift
//  ChefAcademy
//
//  An individual garden plot that can be:
//  - Empty (tap to plant)
//  - Growing (watch the progress!)
//  - Ready (tap to harvest!)
//

import SwiftUI

// MARK: - Plot View
//
// This is a REUSABLE COMPONENT. We use it 4 times in GardenView!
// Instead of copying code, we make ONE component and reuse it.
//

struct PlotView: View {

    // The plot data (what's planted, growth progress, etc.)
    let plot: GardenPlot

    // These are "closures" - functions passed in from the parent view
    // This lets GardenView decide what happens when we tap
    let onTap: () -> Void
    let onHarvest: () -> Void

    // Animation state for the "ready to harvest" bounce
    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            if plot.state == .ready {
                onHarvest()
            } else {
                onTap()
            }
        }) {
            ZStack {
                // Background - the dirt/soil
                plotBackground

                // Content changes based on state
                plotContent
            }
            .frame(height: 150)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .shadow(
                color: Color.AppTheme.sepia.opacity(0.15),
                radius: 5,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlotButtonStyle())
        .onAppear {
            if plot.state == .ready {
                // Start bouncing animation when ready
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
        .onChange(of: plot.state) { _, newState in
            if newState == .ready {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            } else {
                isAnimating = false
            }
        }
    }

    // MARK: - Plot Background

    var plotBackground: some View {
        ZStack {
            // Soil color
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(soilColor)

            // Soil texture lines
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule()
                        .fill(Color.brown.opacity(0.2))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.xl)
        }
    }

    // MARK: - Plot Content

    @ViewBuilder
    var plotContent: some View {
        switch plot.state {
        case .empty:
            emptyPlotContent

        case .growing:
            growingPlotContent

        case .ready:
            readyPlotContent

        case .needsWater:
            needsWaterContent
        }
    }

    // MARK: - Empty Plot

    var emptyPlotContent: some View {
        VStack(spacing: AppSpacing.sm) {
            // Plus icon
            ZStack {
                Circle()
                    .fill(Color.AppTheme.cream.opacity(0.8))
                    .frame(width: 50, height: 50)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.AppTheme.sage)
            }

            Text("Tap to plant")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.cream)
        }
    }

    // MARK: - Growing Plot

    var growingPlotContent: some View {
        VStack(spacing: AppSpacing.sm) {
            // Plant emoji - gets bigger as it grows!
            if let veg = plot.vegetable {
                Text(veg.emoji)
                    .font(.system(size: plantSize))
                    .scaleEffect(0.3 + (plot.growthProgress * 0.7))
            }

            // Growth progress bar
            VStack(spacing: 4) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.AppTheme.cream.opacity(0.5))
                            .frame(height: 8)

                        // Progress fill
                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: geometry.size.width * plot.growthProgress, height: 8)
                    }
                }
                .frame(height: 8)

                // Percentage text
                Text("\(Int(plot.growthProgress * 100))%")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.cream)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    // MARK: - Ready to Harvest

    var readyPlotContent: some View {
        VStack(spacing: AppSpacing.sm) {
            // Full-grown plant with bounce animation
            if let veg = plot.vegetable {
                VStack(spacing: 4) {
                    Text(veg.emoji)
                        .font(.system(size: 44))
                        .scaleEffect(isAnimating ? 1.1 : 1.0)

                    // Sparkle effect
                    HStack(spacing: 2) {
                        Text("✨")
                        Text("✨")
                        Text("✨")
                    }
                    .font(.system(size: 12))
                }
            }

            // Harvest button hint
            Text("Tap to harvest!")
                .font(.AppTheme.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.AppTheme.goldenWheat)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(Color.AppTheme.cream.opacity(0.9))
                .cornerRadius(8)
        }
    }

    // MARK: - Needs Water (future feature)

    var needsWaterContent: some View {
        VStack(spacing: AppSpacing.sm) {
            if let veg = plot.vegetable {
                Text(veg.emoji)
                    .font(.system(size: 32))
                    .opacity(0.6)
            }

            Text("💧 Needs water!")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.cream)
        }
    }

    // MARK: - Computed Properties

    // Soil color changes based on state
    var soilColor: Color {
        switch plot.state {
        case .empty:
            return Color(red: 0.4, green: 0.3, blue: 0.2) // Brown soil
        case .growing:
            return Color(red: 0.35, green: 0.28, blue: 0.18) // Darker, richer soil
        case .ready:
            return Color(red: 0.3, green: 0.35, blue: 0.25) // Greenish tint
        case .needsWater:
            return Color(red: 0.5, green: 0.35, blue: 0.25) // Dry, lighter soil
        }
    }

    // Plant size grows with progress
    var plantSize: CGFloat {
        let baseSize: CGFloat = 24
        let maxSize: CGFloat = 44
        return baseSize + (maxSize - baseSize) * plot.growthProgress
    }
}

// MARK: - Plot Button Style
//
// Custom button style that adds a nice press effect
//

struct PlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Empty Plot") {
    PlotView(
        plot: GardenPlot(id: 0, state: .empty),
        onTap: { print("Tapped!") },
        onHarvest: { print("Harvested!") }
    )
    .frame(width: 170, height: 150)
    .padding()
}

#Preview("Growing Plot") {
    PlotView(
        plot: {
            var plot = GardenPlot(id: 1)
            plot.state = .growing
            plot.vegetable = .carrot
            plot.plantedDate = Date().addingTimeInterval(-30) // 30 seconds ago
            return plot
        }(),
        onTap: { print("Tapped!") },
        onHarvest: { print("Harvested!") }
    )
    .frame(width: 170, height: 150)
    .padding()
}

#Preview("Ready Plot") {
    PlotView(
        plot: {
            var plot = GardenPlot(id: 2)
            plot.state = .ready
            plot.vegetable = .tomato
            plot.plantedDate = Date().addingTimeInterval(-100)
            return plot
        }(),
        onTap: { print("Tapped!") },
        onHarvest: { print("Harvested!") }
    )
    .frame(width: 170, height: 150)
    .padding()
}
