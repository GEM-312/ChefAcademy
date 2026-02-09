//
//  PlotView.swift
//  ChefAcademy
//
//  An individual garden plot that can be:
//  - Empty (tap to plant) — shows "+" icon
//  - Growing (progress bar + small veggie)
//  - Ready (full veggie illustration + harvest badge)
//
//  Clean style — no soil circles, just the content.
//

import SwiftUI

// MARK: - Plot View

struct PlotView: View {

    let plot: GardenPlot
    let onTap: () -> Void
    let onHarvest: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            if plot.state == .ready {
                onHarvest()
            } else {
                onTap()
            }
        }) {
            plotContent
                .frame(width: 100, height: 110)
        }
        .buttonStyle(PlotButtonStyle())
        .onAppear {
            if plot.state == .ready {
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

    // MARK: - Empty Plot — just a "+" and "Plant" label

    var emptyPlotContent: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.7))
                    .frame(width: 70, height: 70)

                Circle()
                    .strokeBorder(
                        Color.AppTheme.sepia.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.AppTheme.sage)
            }

            Text("Plant")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.sepia)
        }
    }

    // MARK: - Growing Plot — veggie image + progress bar

    var growingPlotContent: some View {
        VStack(spacing: 4) {
            // Beige circle background with veggie illustration
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.85))
                    .frame(width: 80, height: 80)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .scaleEffect(0.6 + (plot.growthProgress * 0.4))
                        .opacity(0.5 + (plot.growthProgress * 0.5))
                }
            }

            // Progress bar
            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.AppTheme.parchment)
                            .frame(height: 6)

                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: geo.size.width * plot.growthProgress, height: 6)
                    }
                }
                .frame(width: 70, height: 6)

                Text("\(Int(plot.growthProgress * 100))%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.AppTheme.sepia)
            }
        }
    }

    // MARK: - Ready to Harvest — full veggie + sparkles

    var readyPlotContent: some View {
        VStack(spacing: 4) {
            ZStack {
                // Beige circle background
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.9))
                    .frame(width: 85, height: 85)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 65, height: 65)
                        .scaleEffect(isAnimating ? 1.08 : 1.0)
                }

                // Sparkles
                Text("✨")
                    .font(.system(size: 14))
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .offset(x: -40, y: -30)

                Text("✨")
                    .font(.system(size: 11))
                    .opacity(isAnimating ? 0.3 : 1.0)
                    .offset(x: 38, y: -25)
            }

            // Harvest badge
            Text("Harvest!")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color.AppTheme.goldenWheat)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.AppTheme.warmCream.opacity(0.9))
                .cornerRadius(8)
        }
    }

    // MARK: - Needs Water

    var needsWaterContent: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.7))
                    .frame(width: 80, height: 80)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .opacity(0.4)
                        .saturation(0.2)
                }
            }

            Text("💧 Water me!")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.sepia)
        }
    }
}

// MARK: - Plot Button Style

struct PlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Empty Plot") {
    ZStack {
        Color.AppTheme.cream
        PlotView(
            plot: GardenPlot(id: 0, state: .empty),
            onTap: { print("Tapped!") },
            onHarvest: { print("Harvested!") }
        )
    }
}

#Preview("Growing Plot") {
    ZStack {
        Color.AppTheme.cream
        PlotView(
            plot: {
                var plot = GardenPlot(id: 1)
                plot.state = .growing
                plot.vegetable = .carrot
                plot.plantedDate = Date().addingTimeInterval(-30)
                return plot
            }(),
            onTap: { print("Tapped!") },
            onHarvest: { print("Harvested!") }
        )
    }
}

#Preview("Ready Plot") {
    ZStack {
        Color.AppTheme.cream
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
    }
}
