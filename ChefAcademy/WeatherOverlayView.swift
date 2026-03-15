//
//  WeatherOverlayView.swift
//  ChefAcademy
//
//  Fun animated weather effects overlaid on the garden map!
//  Rain drops, snowflakes, sunshine glow, and more.
//  All touches pass through to the garden beneath.
//

import SwiftUI

// MARK: - Weather Overlay View

struct WeatherOverlayView: View {
    let weather: GardenWeather
    let mapWidth: CGFloat
    let mapHeight: CGFloat

    var body: some View {
        ZStack {
            switch weather {
            case .sunny:
                SunshineOverlay()
            case .partlyCloudy:
                PartlyCloudyOverlay()
            case .cloudy:
                CloudOverlay()
            case .rainy:
                RainOverlay(width: mapWidth, height: mapHeight)
            case .stormy:
                StormOverlay(width: mapWidth, height: mapHeight)
            case .snowy:
                SnowOverlay(width: mapWidth, height: mapHeight)
            case .windy:
                WindOverlay(width: mapWidth)
            }
        }
        .allowsHitTesting(false) // All touches pass through!
        .animation(.easeInOut(duration: 1.0), value: weather)
    }
}

// MARK: - Sunshine Overlay
/// Warm golden glow at the top of the garden

struct SunshineOverlay: View {
    @State private var pulse = false

    var body: some View {
        VStack {
            ZStack {
                // Golden radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.3),
                                Color.orange.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .opacity(pulse ? 0.6 : 0.4)

                // Sun icon
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow.opacity(0.5))
                    .rotationEffect(.degrees(pulse ? 15 : -15))
            }
            .offset(x: 60, y: -20)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Partly Cloudy Overlay

struct PartlyCloudyOverlay: View {
    @State private var cloudOffset: CGFloat = -50
    @State private var sunPulse = false

    var body: some View {
        VStack {
            ZStack {
                // Small sun peeking out
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(sunPulse ? 1.1 : 1.0)
                    .offset(x: 40, y: -10)

                // Drifting cloud
                Image(systemName: "cloud.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.6))
                    .offset(x: cloudOffset, y: 10)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                cloudOffset = 50
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                sunPulse = true
            }
        }
    }
}

// MARK: - Cloud Overlay

struct CloudOverlay: View {
    @State private var cloud1X: CGFloat = -30
    @State private var cloud2X: CGFloat = 20

    var body: some View {
        VStack {
            ZStack {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
                    .offset(x: cloud1X, y: 0)

                Image(systemName: "cloud.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.25))
                    .offset(x: cloud2X, y: 20)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                cloud1X = 30
            }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                cloud2X = -20
            }
        }
    }
}

// MARK: - Rain Overlay
/// Animated rain drops falling down

struct RainOverlay: View {
    let width: CGFloat
    let height: CGFloat

    @State private var drops: [RainDrop] = []
    @State private var timer: Timer?

    struct RainDrop: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat
        let size: CGFloat
    }

    var body: some View {
        ZStack {
            // Dark cloud at top
            Image(systemName: "cloud.rain.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.4))
                .position(x: width * 0.4, y: 30)

            // Rain drops
            ForEach(drops) { drop in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: drop.size, height: drop.size * 4)
                    .position(x: drop.x, y: drop.y)
            }
        }
        .onAppear { startRain() }
        .onDisappear { timer?.invalidate() }
    }

    private func startRain() {
        // Spawn initial drops
        drops = (0..<15).map { _ in
            RainDrop(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                speed: CGFloat.random(in: 3...6),
                size: CGFloat.random(in: 2...3)
            )
        }

        // Animate drops falling
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            for i in drops.indices {
                drops[i].y += drops[i].speed
                if drops[i].y > height {
                    drops[i].y = -10
                    drops[i].x = CGFloat.random(in: 0...width)
                }
            }
        }
    }
}

// MARK: - Storm Overlay

struct StormOverlay: View {
    let width: CGFloat
    let height: CGFloat

    @State private var drops: [RainOverlay.RainDrop] = []
    @State private var timer: Timer?
    @State private var flashOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dark tint
            Color.black.opacity(0.1)

            // Lightning flash
            Color.white.opacity(flashOpacity)

            // Storm cloud
            Image(systemName: "cloud.bolt.rain.fill")
                .font(.system(size: 55))
                .foregroundColor(.gray.opacity(0.5))
                .position(x: width * 0.5, y: 30)

            // Rain drops (heavier)
            ForEach(drops) { drop in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: drop.size, height: drop.size * 5)
                    .position(x: drop.x, y: drop.y)
            }
        }
        .onAppear {
            startStorm()
            triggerLightning()
        }
        .onDisappear { timer?.invalidate() }
    }

    private func startStorm() {
        drops = (0..<20).map { _ in
            RainOverlay.RainDrop(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                speed: CGFloat.random(in: 5...8),
                size: CGFloat.random(in: 2...4)
            )
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            for i in drops.indices {
                drops[i].y += drops[i].speed
                if drops[i].y > height {
                    drops[i].y = -10
                    drops[i].x = CGFloat.random(in: 0...width)
                }
            }
        }
    }

    private func triggerLightning() {
        // Random lightning flashes every 5-10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 5...10)) {
            withAnimation(.easeIn(duration: 0.1)) { flashOpacity = 0.3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0 }
            }
            triggerLightning() // Schedule next flash
        }
    }
}

// MARK: - Snow Overlay

struct SnowOverlay: View {
    let width: CGFloat
    let height: CGFloat

    @State private var flakes: [Snowflake] = []
    @State private var timer: Timer?

    struct Snowflake: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let speed: CGFloat
        let drift: CGFloat // Horizontal wobble
        let size: CGFloat
        var phase: CGFloat = 0
    }

    var body: some View {
        ZStack {
            // Light blue tint
            Color.cyan.opacity(0.05)

            // Snow cloud
            Image(systemName: "cloud.snow.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.35))
                .position(x: width * 0.5, y: 25)

            // Snowflakes
            ForEach(flakes) { flake in
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: flake.size, height: flake.size)
                    .position(x: flake.x, y: flake.y)
            }
        }
        .onAppear { startSnow() }
        .onDisappear { timer?.invalidate() }
    }

    private func startSnow() {
        flakes = (0..<20).map { _ in
            Snowflake(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                speed: CGFloat.random(in: 0.5...1.5),
                drift: CGFloat.random(in: 0.3...1.0),
                size: CGFloat.random(in: 3...6)
            )
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            for i in flakes.indices {
                flakes[i].y += flakes[i].speed
                flakes[i].phase += 0.05
                flakes[i].x += sin(flakes[i].phase) * flakes[i].drift // Gentle sway
                if flakes[i].y > height {
                    flakes[i].y = -10
                    flakes[i].x = CGFloat.random(in: 0...width)
                }
            }
        }
    }
}

// MARK: - Wind Overlay

struct WindOverlay: View {
    let width: CGFloat

    @State private var line1X: CGFloat = -100
    @State private var line2X: CGFloat = -60
    @State private var line3X: CGFloat = -80

    var body: some View {
        ZStack {
            // Wind streaks (thin lines blowing across)
            WindStreak()
                .stroke(Color.AppTheme.sage.opacity(0.3), lineWidth: 1.5)
                .frame(width: 80, height: 8)
                .offset(x: line1X, y: 60)

            WindStreak()
                .stroke(Color.AppTheme.sage.opacity(0.25), lineWidth: 1)
                .frame(width: 60, height: 6)
                .offset(x: line2X, y: 120)

            WindStreak()
                .stroke(Color.AppTheme.sage.opacity(0.2), lineWidth: 1.5)
                .frame(width: 70, height: 7)
                .offset(x: line3X, y: 180)

            // Wind icon
            Image(systemName: "wind")
                .font(.system(size: 30))
                .foregroundColor(Color.AppTheme.sage.opacity(0.4))
                .position(x: width * 0.7, y: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                line1X = width + 100
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false).delay(0.3)) {
                line2X = width + 80
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.7)) {
                line3X = width + 90
            }
        }
    }
}

/// A simple curved line shape for wind streaks
struct WindStreak: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: 0)
        )
        return path
    }
}

// MARK: - Weather Badge (for GardenView header)

struct WeatherBadge: View {
    @ObservedObject var weatherService: GardenWeatherService
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: weatherService.currentWeather.systemIcon)
                .foregroundColor(weatherService.currentWeather.iconColor)
                .font(.system(size: isIPad ? 18 : 14))

            Text("\(weatherService.temperature)°")
                .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .padding(.horizontal, isIPad ? AppSpacing.md : AppSpacing.sm)
        .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)
        .background(Color.AppTheme.warmCream.opacity(0.9))
        .cornerRadius(20)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ForEach(GardenWeather.allCases, id: \.self) { weather in
            HStack {
                Image(systemName: weather.systemIcon)
                    .foregroundColor(weather.iconColor)
                Text(weather.displayName)
                Spacer()
                Text("x\(String(format: "%.2f", weather.growthMultiplier))")
            }
            .padding(.horizontal)
        }
    }
}
